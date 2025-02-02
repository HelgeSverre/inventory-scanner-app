import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';

part 'scan_sessions.g.dart';

@HiveType(typeId: 0)
class ScanEvent {
  @HiveField(0)
  final String barcode;

  @HiveField(1)
  final String barcodeFormat;

  @HiveField(2)
  final DateTime timestamp;

  ScanEvent({
    required this.barcode,
    required this.barcodeFormat,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'barcode_type': barcodeFormat,
        'timestamp': timestamp.toIso8601String(),
      };
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
  List<ScanEvent> events;

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
    List<ScanEvent>? events,
    this.isSynced = false,
    this.lastError,
    this.lastSyncAttempt,
  }) : events = events ?? [];

  // Helper method to get count for a specific barcode
  int getCount(String barcode) {
    return events.where((e) => e.barcode == barcode).length;
  }

  // Helper to get unique barcodes with their counts
  List<MapEntry<String, int>> get barcodeCounts {
    final counts = <String, int>{};
    for (final event in events) {
      counts[event.barcode] = (counts[event.barcode] ?? 0) + 1;
    }
    return counts.entries.toList();
  }

  // Helper to get unique barcodes with their counts
  List<MapEntry<String, int>> get sortedBarcodeCounts {
    return barcodeCounts
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(5);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt?.toIso8601String(),
        'events': events.map((event) => event.toJson()).toList(),
        'is_synced': isSynced,
      };

  Future<File> exportScanEventsToCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/session_${id}_export.csv');
    final deviceName = Settings.getValue<String>(
      'device_name',
      defaultValue: 'Unknown Device',
    );
    final location = Settings.getValue<String>(
      'device_location',
      defaultValue: '',
    );

    final header = ['Timestamp', 'Barcode', 'Type', 'Device', 'Location'];
    final rows = events
        .map((event) => [
              event.timestamp.toIso8601String(),
              event.barcode,
              event.barcodeFormat,
              deviceName,
              location,
            ])
        .toList();

    rows.insert(0, header);
    final csvData = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csvData);

    return file;
  }
}

class ScannerModel extends Model {
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
    Hive.registerAdapter(ScanEventAdapter());
    Hive.registerAdapter(ScanSessionAdapter());

    _sessionsBox = await Hive.openBox<ScanSession>('scan_sessions');
  }

  // Session Management
  Future<void> startNewSession([String? name]) async {
    var prefix = Settings.getValue<String>(
          'file_prefix',
          defaultValue: 'Scan on ',
        ) ??
        'Scan on ';

    _currentSession = ScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? '${prefix} ${DateTime.now().toString().split(' ')[0]}',
      startedAt: DateTime.now(),
    );

    await _sessionsBox.put(_currentSession!.id, _currentSession!);

    notifyListeners();
  }

  void resumeSession(ScanSession session) {
    _currentSession = session;
    notifyListeners();
  }

  leaveSession(ScannerModel model) async {
    await _currentSession!.save();
    _currentSession = null;
    notifyListeners();
  }

  void endCurrentSession() async {
    if (_currentSession != null) {
      _currentSession!.finishedAt = DateTime.now();
      await _currentSession!.save();
      _currentSession = null;
      notifyListeners();
    }
  }

  Future<void> removeBarcode(String barcode) async {
    if (_currentSession != null) {
      _currentSession!.events.removeWhere((e) => e.barcode == barcode);
      await _currentSession!.save();
      notifyListeners();
    }
  }

  Future<void> removeLastEventForBarcode(String barcode) async {
    if (_currentSession != null) {
      final index = _currentSession!.events.lastIndexWhere(
        (e) => e.barcode == barcode,
      );

      if (index != -1) {
        _currentSession!.events.removeAt(index);
        await _currentSession!.save();
        notifyListeners();
      }
    }
  }

  Future<void> incrementScanCountForBarcode(String barcode) async {
    if (_currentSession != null) {
      var lastScan = _currentSession?.events.lastWhere(
        (e) => e.barcode == barcode,
      );

      if (lastScan == null) return;

      final event = ScanEvent(
        barcode: lastScan.barcode,
        barcodeFormat: lastScan.barcodeFormat,
        timestamp: DateTime.now(),
      );

      _currentSession!.events.add(event);
      await _currentSession!.save();
      notifyListeners();
    }
  }

  Future<void> undoLastScan() async {
    if (_currentSession != null && _currentSession!.events.isNotEmpty) {
      _currentSession!.events.removeLast();
      await _currentSession!.save();
      notifyListeners();
    }
  }

  Future<void> deleteScan(int index) async {
    if (_currentSession != null && index < _currentSession!.events.length) {
      _currentSession!.events.removeAt(index);
      await _currentSession!.save();
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

  Future<bool> processScan(Barcode barcode) async {
    if (_currentSession == null) return false;

    print('======== SCANNED: $barcode - ${barcode.format.name}');

    // Check time between events setting
    final double? minTimeBetweenScans = Settings.getValue<double>(
      'min_time_between_scans',
      defaultValue: 1000.0,
    );

    if (_lastScanTime != null) {
      final diff = DateTime.now().difference(_lastScanTime!).inMilliseconds;
      if (diff < minTimeBetweenScans!) return false;
    }

    // Create and add the scan event
    final event = ScanEvent(
      barcode: barcode.rawValue.toString(),
      barcodeFormat: barcode.format.name,
      timestamp: DateTime.now(),
    );

    _currentSession!.events.add(event);
    await _currentSession!.save();
    _lastScanTime = DateTime.now();

    // Handle instant sync if enabled
    if (Settings.getValue<bool>('instant_sync', defaultValue: false) ?? false) {
      await _syncViaHttp(_currentSession!);
    }

    notifyListeners();
    return true;
  }

  bool get syncViaHttp {
    return Settings.getValue<bool>('enable_http', defaultValue: false) ?? false;
  }

  bool get syncViaFtp {
    return Settings.getValue<bool>('enable_ftp', defaultValue: false) ?? false;
  }

  Future<void> syncSession(ScanSession session) async {
    try {
      session.lastSyncAttempt = DateTime.now();

      if (syncViaHttp) {
        await _syncViaHttp(session);
      }

      if (syncViaFtp) {
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
      'events': session.events.map((scan) => scan.toJson()).toList(),
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
    final csvFile = await session.exportScanEventsToCsv();
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
        user: username ?? '',
        pass: password ?? '',
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
      'Stock'
    ];

    final rows = _currentSession!.events
        .map((scan) => [
              scan.timestamp.toIso8601String(),
              deviceName,
              location,
              scan.barcode,
              scan.barcodeFormat,
            ])
        .toList();

    rows.insert(0, header);

    return const ListToCsvConverter().convert(rows);
  }
}
