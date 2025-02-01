import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';

part 'scan_sessions.g.dart';

@HiveType(typeId: 0)
class ScanItem {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final String barcodeType;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String? productName;

  @HiveField(4)
  final int? currentStock;

  ScanItem({
    required this.barcode,
    required this.barcodeType,
    required this.timestamp,
    this.productName,
    this.currentStock,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'barcode_type': barcodeType,
        'timestamp': timestamp.toIso8601String(),
        'product_name': productName,
        'current_stock': currentStock,
      };

  List<dynamic> toCsvRow() => [
        timestamp.toIso8601String(),
        barcode,
        barcodeType,
        productName ?? '',
        currentStock?.toString() ?? '',
      ];
}

@HiveType(typeId: 1)
class ScanSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final DateTime startedAt;

  @HiveField(3)
  DateTime? finishedAt;

  @HiveField(4)
  List<ScanItem> scans;

  @HiveField(5)
  bool isSynced;

  @HiveField(6)
  String? lastError;

  @HiveField(7)
  DateTime? lastSyncAttempt;

  ScanSession({
    required this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    List<ScanItem>? scans,
    this.isSynced = false,
    this.lastError,
    this.lastSyncAttempt,
  }) : scans = scans ?? [];

  Future<File> exportToCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/session_${id}_export.csv');

    final header = ['Timestamp', 'Barcode', 'Type', 'Product Name', 'Stock'];
    final rows = scans.map((scan) => scan.toCsvRow()).toList();
    rows.insert(0, header);

    final csvData = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csvData);

    return file;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'device_name': Settings.getValue<String>('device_name',
            defaultValue: 'Unknown Device'),
        'device_location':
            Settings.getValue<String>('device_location', defaultValue: ''),
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt?.toIso8601String(),
        'scans': scans.map((scan) => scan.toJson()).toList(),
        'is_synced': isSynced,
      };
}

class ScannerModel extends Model {
  static const String _sessionsBoxName = 'scanning_sessions';
  late Box<ScanSession> _sessionsBox;
  ScanSession? _currentSession;
  DateTime? _lastScanTime;

  // Getters
  List<ScanSession> get sessions => _sessionsBox.values.toList();

  ScanSession? get currentSession => _currentSession;

  bool get hasActiveSession => _currentSession != null;

  // Initialize Hive and load data
  Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(ScanSessionAdapter());
    Hive.registerAdapter(ScanItemAdapter());

    _sessionsBox = await Hive.openBox<ScanSession>(_sessionsBoxName);
  }

  // Session Management
  Future<void> startNewSession([String? name]) async {
    _currentSession = ScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? 'Scan on ${DateTime.now().toString().split(' ')[0]}',
      startedAt: DateTime.now(),
    );
    await _sessionsBox.put(
      _currentSession!.id,
      _currentSession!,
    );

    notifyListeners();
  }

  void endCurrentSession() async {
    if (_currentSession != null) {
      _currentSession!.finishedAt = DateTime.now();
      _currentSession!.save();
      _currentSession = null;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
    notifyListeners();
  }

  Future<void> renameSession(String id, String newName) async {
    final session = _sessionsBox.get(id);
    if (session != null) {
      session.name = newName;
      await session.save();
      notifyListeners();
    }
  }

  Future<void> clearAllSessions() async {
    await _sessionsBox.clear();
    notifyListeners();
  }

  Future<bool> processScan(String barcode, String barcodeType) async {
    if (_currentSession == null) return false;

    // Check time between scans setting
    final double? minTimeBetweenScans = Settings.getValue<double>(
      'min_time_between_scans',
      defaultValue: 1000.0,
    );

    if (_lastScanTime != null) {
      final timeSinceLastScan =
          DateTime.now().difference(_lastScanTime!).inMilliseconds;
      if (timeSinceLastScan < minTimeBetweenScans!) return false;
    }

    final scan = ScanItem(
      barcode: barcode,
      barcodeType: barcodeType,
      timestamp: DateTime.now(),
    );

    _currentSession!.scans.add(scan);
    _lastScanTime = DateTime.now();

    if (Settings.getValue<bool>('instant_sync', defaultValue: false) ?? false) {
      await _syncScan(scan);
    }

    notifyListeners();
    return true;
  }

  Future<void> syncSession(ScanSession session) async {
    try {
      session.lastSyncAttempt = DateTime.now();

      if (Settings.getValue<bool>('enable_http', defaultValue: false) ??
          false) {
        await _syncViaHttp(session);
      }

      if (Settings.getValue<bool>('enable_ftp', defaultValue: false) ?? false) {
        await _syncViaFtp(session);
      }

      session.isSynced = true;
      session.lastError = null;
    } catch (e) {
      session.lastError = e.toString();
    } finally {
      await session.save();
      notifyListeners();
    }
  }

  Future<void> _syncViaHttp(ScanSession session) async {
    final url = Settings.getValue<String>('http_url', defaultValue: '');
    if (url == null || url.isEmpty) {
      throw Exception('HTTP URL not configured');
    }

    final method =
        Settings.getValue<String>('http_method', defaultValue: 'POST');
    final username =
        Settings.getValue<String>('http_username', defaultValue: '');
    final password =
        Settings.getValue<String>('http_password', defaultValue: '');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Add basic auth if credentials are provided
    var hasUsername = (username?.isNotEmpty ?? false);
    var hasPassword = (password?.isNotEmpty ?? false);

    if (hasUsername && hasPassword) {
      final basicAuth = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $basicAuth';
    }

    final payload = {
      'session_id': session.id,
      'session_name': session.name,
      'started_at': session.startedAt.toIso8601String(),
      'finished_at': session.finishedAt?.toIso8601String(),
      'scans': session.scans.map((scan) => scan.toJson()).toList(),
      'device_info': await _getDeviceInfo(),
    };

    http.Response response;
    if (method == 'POST') {
      response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      );
    } else {
      // For GET, encode data in query parameters
      final queryParams = {
        'data': base64Encode(utf8.encode(jsonEncode(payload))),
      };
      response = await http.get(
        Uri.parse(url).replace(queryParameters: queryParams),
        headers: headers,
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
          'HTTP sync failed: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _syncViaFtp(ScanSession session) async {
    final server = Settings.getValue<String>('ftp_server', defaultValue: '');
    if (server == null || server.isEmpty) {
      throw Exception('FTP server not configured');
    }

    final port = int.tryParse(
            Settings.getValue<String>('ftp_port', defaultValue: '21') ??
                '21') ??
        21;
    final username =
        Settings.getValue<String>('ftp_username', defaultValue: '');
    final password =
        Settings.getValue<String>('ftp_password', defaultValue: '');
    final useSftp =
        Settings.getValue<bool>('use_sftp', defaultValue: true) ?? true;

    // Export session to CSV first
    final csvFile = await session.exportToCsv();
    final fileName =
        'scan_session_${session.id}_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (useSftp) {
      // SFTP implementation would go here
      // Note: Current ftpconnect package doesn't support SFTP
      // You would need to add ssh package for SFTP support
      throw UnimplementedError('SFTP not yet implemented');
    } else {
      final ftpClient = FTPConnect(
        server,
        port: port,
        user: username ?? "",
        pass: password ?? "",
      );

      try {
        await ftpClient.connect();
        await ftpClient.uploadFile(csvFile, sRemoteName: fileName);
        await ftpClient.disconnect();
      } catch (e) {
        await ftpClient.disconnect();
        throw Exception('FTP upload failed: $e');
      }
    }
  }

  Future<void> _syncScan(ScanItem scan) async {
    // Only sync individual scans if HTTP is enabled and instant sync is on
    if (!(Settings.getValue<bool>('enable_http', defaultValue: false) ??
            false) ||
        !(Settings.getValue<bool>('instant_sync', defaultValue: false) ??
            false)) {
      return;
    }

    final url = Settings.getValue<String>('http_url', defaultValue: '');
    if (url == null || url.isEmpty) return;

    try {
      final payload = {
        'scan': scan.toJson(),
        'device_info': await _getDeviceInfo(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Instant sync failed: ${response.statusCode}');
      }
    } catch (e) {
      // Log error but don't rethrow - we don't want to interrupt scanning
      print('Warning: Instant sync failed: $e');
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    // Basic device info - you could expand this
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0', // You should get this from your pubspec
    };
  }

// Add this utility method to ScanSession class for CSV export
  Future<String> exportToString() async {
    final deviceName = Settings.getValue<String>(
      'device_name',
      defaultValue: 'Unknown Device',
    );
    final location = Settings.getValue<String>(
      'device_location',
      defaultValue: '',
    );

    final header = [
      'Timestamp',
      'Device',
      'Location',
      'Barcode',
      'Type',
      'Product Name',
      'Stock'
    ];

    final rows = _currentSession!.scans
        .map((scan) => [
              scan.timestamp.toIso8601String(),
              deviceName,
              location,
              scan.barcode,
              scan.barcodeType,
              scan.productName ?? '',
              scan.currentStock?.toString() ?? '',
            ])
        .toList();

    rows.insert(0, header);

    return const ListToCsvConverter().convert(rows);
  }
}
