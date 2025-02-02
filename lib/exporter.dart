// lib/services/export/data_exporter.dart
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:http/http.dart' as http;
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DataExporter {
  static Future<bool> saveCsvToDisk(ScanSession session) async {
    // Let user pick a directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      print("User canceled the directory selection.");
      return false;
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    // Save files in the chosen directory
    await _createCsvEventLog(session, Directory(selectedDirectory), timestamp);
    await _createCsvSummary(session, Directory(selectedDirectory), timestamp);

    return true;
  }

  static Future<bool> saveJsonToDisk(ScanSession session) async {
    // Let user pick a directory
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) {
      print("User canceled the directory selection.");
      return false;
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    final jsonString = const JsonEncoder.withIndent('  ').convert(
      _formatJson(session),
    );

    final file = File(path.join(
      selectedDirectory,
      'session_${session.id}_events_$timestamp.json',
    ));

    await file.writeAsString(jsonString);
    print('File saved to: ${file.path}');

    return true;
  }

  // File export methods
  static Future<void> shareCsv(ScanSession session) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    final eventLog = await _createCsvEventLog(session, directory, timestamp);
    final summary = await _createCsvSummary(session, directory, timestamp);

    await Share.shareXFiles(
      [
        XFile(eventLog.path),
        XFile(summary.path),
      ],
      subject: 'Scan Session ${session.name} - CSV Export',
    );

    // Cleanup
    await Future.wait([
      eventLog.delete(),
      summary.delete(),
    ]);
  }

  static Future<void> shareJson(ScanSession session) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(
      _formatJson(session),
    );
    await Share.share(
      jsonString,
      subject: 'Scan Session ${session.name} - JSON Export',
    );
  }

  static String _replacePlaceholders(
    String template, {
    required ScanSession session,
    required String type, // 'events' or 'inventory'
  }) {
    final date = DateTime.now();
    final device = Settings.getValue<String>('device_name') ?? "";
    final location = Settings.getValue<String>('device_location') ?? "";
    final timestamp = date.toIso8601String().replaceAll(':', '-');

    return template
        .replaceAll('[DATE]',
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')
        .replaceAll('[YEAR]', date.year.toString())
        .replaceAll('[MONTH]', date.month.toString().padLeft(2, '0'))
        .replaceAll('[DAY]', date.day.toString().padLeft(2, '0'))
        .replaceAll('[DEVICE]', device)
        .replaceAll('[LOCATION]', location)
        .replaceAll('[SESSION_ID]', session.id)
        .replaceAll('[SESSION_NAME]', session.name)
        .replaceAll('[TYPE]', type)
        .replaceAll('[TIMESTAMP]', timestamp);
  }

  static Future<String> _getRemotePath(
      FTPConnect client, ScanSession session, String type) async {
    final template = Settings.getValue<String>('ftp_path') ??
        '/scans/[DATE]/session_[SESSION_ID]_[TYPE].csv';
    final fullPath =
        _replacePlaceholders(template, session: session, type: type);

    // Ensure directory exists
    final dir = path.dirname(fullPath);
    if (dir != '.') {
      final dirs = dir.split('/')..removeWhere((d) => d.isEmpty);
      var currentPath = '';
      for (final d in dirs) {
        currentPath += '/$d';
        await client.createFolderIfNotExist(currentPath);
      }
    }

    return fullPath;
  }

  // Remote export methods
  static Future<void> uploadToFtp(ScanSession session) async {
    final server = Settings.getValue<String>('ftp_server');
    if (server == null || server.isEmpty) {
      throw Exception('FTP server not configured');
    }

    // Validate port
    final portStr = Settings.getValue<String>('ftp_port') ?? '21';
    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      throw Exception('Invalid port number: must be between 1 and 65535');
    }

    final username = Settings.getValue<String>('ftp_username') ?? '';
    final password = Settings.getValue<String>('ftp_password') ?? '';
    final timeout = Settings.getValue<int>('ftp_timeout') ?? 30;
    final useFtps = Settings.getValue<bool>('use_ftps') ?? false;

    // Get transfer settings
    final transferMode =
        Settings.getValue<String>('ftp_transfer_mode') ?? 'passive';
    final transferType =
        Settings.getValue<String>('ftp_transfer_type') ?? 'auto';

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    // Create files
    final eventLog = await _createCsvEventLog(session, directory, timestamp);
    final summary = await _createCsvSummary(session, directory, timestamp);

    // Create FTP client
    final ftpClient = FTPConnect(
      server,
      port: port,
      user: username,
      pass: password,
      timeout: timeout,
      securityType: useFtps ? SecurityType.FTPS : SecurityType.FTP,
    );

    try {
      await ftpClient.connect();

      // Set transfer mode
      if (transferMode == 'active') {
        ftpClient.transferMode = TransferMode.active;
      } else {
        ftpClient.transferMode = TransferMode.passive;
      }

      // Set transfer type if not 'auto'
      if (transferType != 'auto') {
        await ftpClient.setTransferType(
          transferType == 'ascii' ? TransferType.ascii : TransferType.binary,
        );
      }

      // Upload files
      for (final file in [eventLog, summary]) {
        final type = file == eventLog ? 'events' : 'inventory';
        final remotePath = await _getRemotePath(ftpClient, session, type);
        await ftpClient.uploadFile(file, sRemoteName: remotePath);
      }
    } finally {
      await ftpClient.disconnect();

      // Cleanup temporary files
      await Future.wait([
        eventLog.delete(),
        summary.delete(),
      ]);
    }
  }

  static Future<void> uploadToHttp(ScanSession session) async {
    final url = Settings.getValue<String>('http_url');
    if (url == null || url.isEmpty) {
      throw Exception('HTTP URL not configured');
    }

    final headers = {'Content-Type': 'application/json'};
    final username = Settings.getValue<String>('http_username');
    final password = Settings.getValue<String>('http_password');
    final useAuth = Settings.getValue<bool>('http_use_auth') ?? false;

    if (useAuth &&
        username?.isNotEmpty == true &&
        password?.isNotEmpty == true) {
      var basic = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic ${basic}';
    }

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(_formatJson(session)),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP upload failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  static Future<void> uploadToEpcis(ScanSession session) async {
    final url = Settings.getValue<String>('epcis_url');
    if (url == null || url.isEmpty) {
      throw Exception('EPCIS URL not configured');
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_formatEpcis(session)),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'EPCIS upload failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Helper methods for formatting
  static Future<File> _createCsvEventLog(
    ScanSession session,
    Directory directory,
    String timestamp,
  ) async {
    final device = Settings.getValue<String>('device_name',
        defaultValue: 'Unknown Device');
    final location = Settings.getValue<String>(
      'device_location',
      defaultValue: '',
    );

    final rows = [
      // Simple header row with column names
      [
        'timestamp',
        'barcode',
        'format',
        'device',
        'location',
        'session_id',
        'session_name'
      ],

      // Data rows
      ...session.events.map((e) => [
            e.timestamp.toIso8601String(),
            e.barcode,
            e.barcodeFormat,
            device,
            location,
            session.id,
            session.name,
          ]),
    ];

    final file = File(path.join(
      directory.path,
      'session_${session.id}_events_$timestamp.csv',
    ));
    await file.writeAsString(const ListToCsvConverter().convert(rows));
    return file;
  }

  static Future<File> _createCsvSummary(
    ScanSession session,
    Directory directory,
    String timestamp,
  ) async {
    final device = Settings.getValue<String>(
      'device_name',
      defaultValue: 'Unknown Device',
    );
    final location = Settings.getValue<String>(
      'device_location',
      defaultValue: '',
    );

    // Group and sort events
    final barcodeGroups = <String, List<ScanEvent>>{};
    for (final event in session.events) {
      barcodeGroups.putIfAbsent(event.barcode, () => []).add(event);
    }

    final rows = [
      // Simple header row with column names
      [
        'device',
        'location',
        'barcode',
        'format',
        'count',
        'first_scan',
        'last_scan',
        'session_id',
        'session_name'
      ],

      // Data rows
      ...barcodeGroups.entries.map((entry) {
        final events = entry.value
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return [
          device,
          location,
          entry.key,
          events.first.barcodeFormat,
          events.length.toString(),
          events.first.timestamp.toIso8601String(),
          events.last.timestamp.toIso8601String(),
          session.id,
          session.name,
        ];
      }),
    ];

    final file = File(path.join(
      directory.path,
      'session_${session.id}_inventory_$timestamp.csv',
    ));

    await file.writeAsString(const ListToCsvConverter().convert(rows));

    return file;
  }

  static Map<String, dynamic> _formatJson(ScanSession session) {
    final device = Settings.getValue<String>(
      'device_name',
      defaultValue: 'Unknown Device',
    );
    final location = Settings.getValue<String>(
      'device_location',
      defaultValue: '',
    );

    return {
      'session': {
        'id': session.id,
        'name': session.name,
        'startedAt': session.startedAt.toIso8601String(),
        'finishedAt': session.finishedAt?.toIso8601String(),
        'device': device,
        'location': location,
      },
      'events': session.events
          .map((e) => {
                'timestamp': e.timestamp.toIso8601String(),
                'barcode': e.barcode,
                'format': e.barcodeFormat,
              })
          .toList(),
      'summary': session.barcodeCounts
          .map((entry) => {
                'barcode': entry.key,
                'count': entry.value,
              })
          .toList(),
    };
  }

  static Map<String, dynamic> _formatEpcis(ScanSession session) {
    final namespace =
        Settings.getValue<String>('epcis_namespace') ?? 'business';
    final device = Settings.getValue<String>('epcis_device') ?? 'scanner-001';
    final location =
        Settings.getValue<String>('epcis_location') ?? 'location-001';
    final useBatched =
        Settings.getValue<String>('epcis_mode') == 'quantityList';

    return {
      'epcisVersion': '2.0',
      'schemaVersion': '2.0',
      'creationDate': DateTime.now().toIso8601String(),
      'epcisBody': {
        'eventList': useBatched
            ? [
                {
                  'type': 'AggregationEvent',
                  'eventTime': DateTime.now().toIso8601String(),
                  'eventTimeZoneOffset': '+00:00',
                  'parentID': 'urn:$namespace:location:$location',
                  'childEPCs': [],
                  'quantityList': session.barcodeCounts
                      .map((entry) => {
                            'epcClass': 'urn:$namespace:item:${entry.key}',
                            'quantity': entry.value
                          })
                      .toList(),
                  'action': 'ADD',
                  'bizStep': 'urn:epcglobal:cbv:btt:inventory_check',
                  'readPoint': {'id': 'urn:$namespace:location:$location'},
                  'bizLocation': {'id': 'urn:$namespace:device:$device'}
                },
              ]
            : session.events
                .map((event) => {
                      'type': 'ObjectEvent',
                      'eventTime': event.timestamp.toIso8601String(),
                      'eventTimeZoneOffset': '+00:00',
                      'epcList': List.generate(
                        session.getCount(event.barcode),
                        (_) => 'urn:$namespace:item:${event.barcode}',
                      ),
                      'action': 'OBSERVE',
                      'bizStep': 'urn:epcglobal:cbv:btt:inventory_check',
                      'disposition': 'urn:epcglobal:cbv:disp:in_progress',
                      'readPoint': {'id': 'urn:$namespace:location:$location'},
                      'bizLocation': {'id': 'urn:$namespace:device:$device'}
                    })
                .toList(),
      }
    };
  }
}
