// lib/services/export/data_exporter.dart
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:http/http.dart' as http;
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DataExporter {
  // File export methods
  static Future<void> shareCsv(ScanSession session) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    final eventLog = await _createCsvEventLog(session, directory, timestamp);
    final summary = await _createCsvSummary(session, directory, timestamp);

    await Share.shareXFiles(
      [XFile(eventLog.path), XFile(summary.path)],
      subject: 'Scan Session ${session.name} - CSV Export',
    );

    // Cleanup
    await Future.wait([eventLog.delete(), summary.delete()]);
  }

  static Future<void> shareJson(ScanSession session) async {
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(_formatJson(session));
    await Share.share(
      jsonString,
      subject: 'Scan Session ${session.name} - JSON Export',
    );
  }

  // Remote export methods
  static Future<void> uploadToFtp(ScanSession session) async {
    final server = Settings.getValue<String>('ftp_server');
    if (server == null || server.isEmpty) {
      throw Exception('FTP server not configured');
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    // Create files
    final eventLog = await _createCsvEventLog(session, directory, timestamp);
    final summary = await _createCsvSummary(session, directory, timestamp);

    // Upload
    final client = FTPConnect(
      server,
      port: int.tryParse(Settings.getValue<String>('ftp_port') ?? '21') ?? 21,
      user: Settings.getValue<String>('ftp_username') ?? 'anonymous',
      pass: Settings.getValue<String>('ftp_password') ?? '',
    );

    try {
      await client.connect();
      final remotePath = await _createFtpDirectory(client);

      for (final file in [eventLog, summary]) {
        await client.uploadFile(
          file,
          sRemoteName: '$remotePath/${path.basename(file.path)}',
        );
      }
    } finally {
      await client.disconnect();
      // Cleanup
      await Future.wait([eventLog.delete(), summary.delete()]);
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
    final location =
        Settings.getValue<String>('device_location', defaultValue: '');

    final rows = [
      ['Session Name', session.name],
      ['Session ID', session.id],
      ['Start Time', session.startedAt.toIso8601String()],
      ['End Time', session.finishedAt?.toIso8601String() ?? 'Active'],
      ['Device', device],
      ['Location', location],
      [],
      ['Scan Time', 'Barcode', 'Format', 'Device', 'Location'],
      ...session.events.map((e) => [
            e.timestamp.toIso8601String(),
            e.barcode,
            e.barcodeFormat,
            device,
            location,
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
      ScanSession session, Directory directory, String timestamp) async {
    final device = Settings.getValue<String>('device_name',
        defaultValue: 'Unknown Device');
    final location =
        Settings.getValue<String>('device_location', defaultValue: '');

    final barcodeGroups = <String, List<ScanEvent>>{};
    for (final event in session.events) {
      barcodeGroups.putIfAbsent(event.barcode, () => []).add(event);
    }

    final rows = [
      ['Session Name', session.name],
      ['Session ID', session.id],
      ['Total Scans', session.events.length.toString()],
      ['Unique Items', barcodeGroups.length.toString()],
      ['Device', device],
      ['Location', location],
      [],
      ['Barcode', 'Quantity', 'First Scan', 'Last Scan', 'Format'],
      ...barcodeGroups.entries.map((entry) {
        final events = entry.value
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp))
          ..toList();

        return [
          entry.key,
          events.length.toString(),
          events.first.timestamp.toIso8601String(),
          events.last.timestamp.toIso8601String(),
          events.first.barcodeFormat,
        ];
      }),
    ];

    final file = File(
      path.join(directory.path, 'session_${session.id}_summary_$timestamp.csv'),
    );
    await file.writeAsString(const ListToCsvConverter().convert(rows));

    return file;
  }

  static Map<String, dynamic> _formatJson(ScanSession session) {
    final device = Settings.getValue<String>('device_name',
        defaultValue: 'Unknown Device');
    final location =
        Settings.getValue<String>('device_location', defaultValue: '');

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

  static Future<String> _createFtpDirectory(FTPConnect client) async {
    final baseDir = Settings.getValue<String>('ftp_path') ?? '/scans';
    final now = DateTime.now();

    final datePath =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // ex: exports/2025-01-01
    final fullPath = '$baseDir/$datePath';

    await client.createFolderIfNotExist(baseDir);
    await client.createFolderIfNotExist(fullPath);

    return fullPath;
  }
}
