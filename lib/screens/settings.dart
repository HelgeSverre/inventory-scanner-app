import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:http/http.dart' as http;
import 'package:inventory_scanner/screens/qr_scanner.dart';

class AppSettingScreen extends StatefulWidget {
  const AppSettingScreen({super.key});

  @override
  State<AppSettingScreen> createState() => _AppSettingScreenState();
}

class _AppSettingScreenState extends State<AppSettingScreen> {
  Future<void> fetchConfigFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load config: ${response.statusCode}');
      }

      final config = jsonDecode(response.body) as Map<String, dynamic>;

      if (config.isEmpty) {
        throw Exception('Empty configuration');
      }

      // Save the URL
      Settings.setValue("remote_config_url", url);

      // Device Config
      if (config['device'] != null) {
        final device = config['device'] as Map<String, dynamic>;
        await Settings.setValue('device_name', device['name']);
        await Settings.setValue('device_location', device['location']);
      }

      // Scanner Config
      if (config['scanner'] != null) {
        final scanner = config['scanner'] as Map<String, dynamic>;
        await Settings.setValue('min_time_between_scans',
            scanner['min_time_between_scans']?.toDouble());
        await Settings.setValue('instant_sync', scanner['instant_sync']);
      }

      // HTTP Config
      if (config['http'] != null) {
        final http = config['http'] as Map<String, dynamic>;
        await Settings.setValue('enable_http', http['enabled']);
        await Settings.setValue('http_url', http['url']);

        if (http['auth'] != null) {
          final auth = http['auth'] as Map<String, dynamic>;
          await Settings.setValue('http_use_auth', auth['enabled']);
          await Settings.setValue('http_username', auth['username']);
          await Settings.setValue('http_password', auth['password']);
        }
      }

      // FTP Config
      if (config['ftp'] != null) {
        final ftp = config['ftp'] as Map<String, dynamic>;
        await Settings.setValue('enable_ftp', ftp['enabled']);
        await Settings.setValue('ftp_server', ftp['server']);
        await Settings.setValue('ftp_port', ftp['port']);
        await Settings.setValue('ftp_username', ftp['username']);
        await Settings.setValue('ftp_password', ftp['password']);
        await Settings.setValue('ftp_path', ftp['path']);
        await Settings.setValue('use_sftp', ftp['use_sftp']);
        await Settings.setValue('ftp_timeout', ftp['timeout']);
      }

      // EPCIS Config
      if (config['epcis'] != null) {
        final epcis = config['epcis'] as Map<String, dynamic>;
        await Settings.setValue('epcis_namespace', epcis['namespace']);
        await Settings.setValue('epcis_device', epcis['device']);
        await Settings.setValue('epcis_location', epcis['location']);
        await Settings.setValue('epcis_mode', epcis['mode']);
        await Settings.setValue('epcis_url', epcis['url']);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load configuration: $e',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      }
    }
  }

  _scanQrCode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    ).then((url) {
      if (url != null) {
        print(url);
        fetchConfigFromUrl(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var interval = Settings.getValue<double>('min_time_between_scans');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Load config from URL with QR-Code',
            icon: const Icon(Icons.qr_code_outlined),
            onPressed: () => _scanQrCode(),
          ),
        ],
      ),
      body: ListView(
        children: [
          // REMOTE CONFIGURATION
          // -------------------------------------------------------------------
          TextInputSettingsTile(
            title: 'Remote Config URL',
            settingKey: 'remote_config_url',
            helperText: 'URL of the remote configuration service',
            // initialValue: '',
            keyboardType: TextInputType.url,
            onChange: (value) => setState(() => fetchConfigFromUrl(value)),
          ),

          // DEVICE CONFIGURATION
          // -------------------------------------------------------------------
          ExpandableSettingsTile(
            title: 'Device Configuration',
            subtitle: 'Configure device identity and basic settings',
            children: [
              const TextInputSettingsTile(
                title: 'Device Name',
                settingKey: 'device_name',
                initialValue: '',
                helperText: 'Example: Scanner-01',
              ),
              const TextInputSettingsTile(
                title: 'Device Location',
                settingKey: 'device_location',
                initialValue: '',
                helperText: 'Example: Warehouse A, Van-12',
              ),
              const TextInputSettingsTile(
                title: 'Session name prefix',
                settingKey: 'scan_session_prefix',
                initialValue: 'Scan on [DATE]',
                helperText: 'Scan on [DATE]',
              ),
              SliderSettingsTile(
                title: 'Scan Interval (${interval?.toInt()}ms)',
                settingKey: 'min_time_between_scans',
                defaultValue: 1000,
                min: 500,
                max: 5000,
                step: 100,
                subtitle: 'Minimum time between scans in milliseconds',
                decimalPrecision: 0,
                eagerUpdate: true,
                onChange: (value) => setState(() {}),
              ),
              const SwitchSettingsTile(
                title: 'Real-time Sync',
                subtitle: 'Automatically sync scans as they occur (HTTP only)',
                settingKey: 'instant_sync',
                enabledLabel: 'Instant sync',
                disabledLabel: 'Manual sync',
                showDivider: false,
              ),
            ],
          ),

          // EPCIS SETTINGS
          // -------------------------------------------------------------------
          const ExpandableSettingsTile(
            title: 'EPCIS Configuration',
            subtitle: 'Configure EPCIS integration settings',
            children: [
              TextInputSettingsTile(
                title: 'Company Namespace',
                settingKey: 'epcis_namespace',
                initialValue: 'mycompany',
                helperText: 'Your company identifier (Example: initech)',
              ),
              TextInputSettingsTile(
                title: 'Location ID',
                settingKey: 'epcis_location',
                initialValue: '',
                helperText: 'EPCIS location identifier (Example: warehouse-01)',
              ),
              TextInputSettingsTile(
                title: 'Device ID',
                settingKey: 'epcis_device',
                initialValue: '',
                helperText: 'EPCIS device identifier (Example: scanner-01)',
              ),
              RadioSettingsTile(
                title: 'Scan Mode',
                subtitle: 'Choose scan data structure format',
                settingKey: 'epcis_mode',
                showDivider: false,
                values: {
                  'epcList': 'Individual Scans (epcList)',
                  'quantityList': 'Aggregated Counts (quantityList)',
                },
                selected: '',
              ),
              TextInputSettingsTile(
                title: 'HTTP Endpoint',
                settingKey: 'epcis_url',
                initialValue:
                    'https://example.com/epcis/Service/Poll/SimpleEvent',
                helperText: 'API endpoint for EPCIS sync',
                keyboardType: TextInputType.url,
              ),
            ],
          ),

          // DATA EXPORT SETTINGS
          // -------------------------------------------------------------------
          ExpandableSettingsTile(
            title: 'Data Export',
            subtitle: 'Configure data export methods',
            showDivider: false,
            children: [
              // HTTP Export Settings
              const SettingsGroup(
                title: 'HTTP',
                children: [
                  SwitchSettingsTile(
                    title: 'Enable HTTP Export',
                    settingKey: 'enable_http',
                    childrenIfEnabled: [
                      TextInputSettingsTile(
                        title: 'Endpoint URL',
                        settingKey: 'http_url',
                        initialValue: '',
                        helperText: 'HTTP endpoint to receive scan data',
                        keyboardType: TextInputType.url,
                      ),
                      SwitchSettingsTile(
                        title: 'Authentication',
                        settingKey: 'http_use_auth',
                        childrenIfEnabled: [
                          TextInputSettingsTile(
                            title: 'Username',
                            settingKey: 'http_username',
                            initialValue: '',
                          ),
                          TextInputSettingsTile(
                            title: 'Password',
                            settingKey: 'http_password',
                            initialValue: '',
                            obscureText: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // FTP Export Settings
              SettingsGroup(
                title: 'FTP',
                children: [
                  SwitchSettingsTile(
                    title: 'Enable FTP Export',
                    settingKey: 'enable_ftp',
                    defaultValue: false,
                    childrenIfEnabled: [
                      const TextInputSettingsTile(
                        title: 'Server Address',
                        settingKey: 'ftp_server',
                        initialValue: '',
                        helperText: 'FTP server hostname or IP address',
                      ),
                      TextInputSettingsTile(
                        title: 'Port',
                        settingKey: 'ftp_port',
                        initialValue: '21',
                        helperText: 'Default: 21 (FTP), 990 (FTPS)',
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Port is required';
                          }
                          try {
                            final port = int.parse(value);
                            if (port < 1 || port > 65535) {
                              return 'Port must be between 1 and 65535';
                            }
                          } catch (e) {
                            return 'Port must be a number';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.number,
                        errorColor: Colors.red,
                      ),
                      const TextInputSettingsTile(
                        title: 'Username',
                        settingKey: 'ftp_username',
                        initialValue: '',
                      ),
                      const TextInputSettingsTile(
                        title: 'Password',
                        settingKey: 'ftp_password',
                        initialValue: '',
                        obscureText: true,
                      ),
                      const TextInputSettingsTile(
                        title: 'Remote Path Template',
                        settingKey: 'ftp_path',
                        initialValue: '/scans/[DATE]_scans_[TYPE].csv',
                        helperText:
                            'Full path template including filename. Placeholders:\n'
                            '[DATE]=YYYY-MM-DD, [YEAR], [MONTH], [DAY]\n'
                            '[SESSION_ID], [SESSION_NAME], [TYPE]\n'
                            '[DEVICE], [LOCATION], [TIMESTAMP]',
                      ),
                      const RadioSettingsTile(
                        title: 'Transfer Mode',
                        settingKey: 'ftp_transfer_mode',
                        selected: 'passive',
                        values: {
                          'passive': 'Passive Mode (recommended)',
                          'active': 'Active Mode',
                        },
                        subtitle:
                            'Passive mode is typically better for connections through firewalls',
                      ),
                      const RadioSettingsTile(
                        title: 'Transfer Type',
                        settingKey: 'ftp_transfer_type',
                        selected: 'auto',
                        values: {
                          'auto': 'Auto-detect',
                          'ascii': 'ASCII (text files)',
                          'binary': 'Binary (all files)',
                        },
                        subtitle: 'Auto-detect will choose based on file type',
                      ),
                      const SwitchSettingsTile(
                        title: 'Use FTPS (Secure FTP)',
                        settingKey: 'use_ftps',
                        defaultValue: false,
                      ),
                      const TextInputSettingsTile(
                        title: 'Timeout (seconds)',
                        settingKey: 'ftp_timeout',
                        initialValue: "30",
                        helperText: 'FTP connection timeout in seconds',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
