import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class AppSettingScreen extends StatefulWidget {
  const AppSettingScreen({super.key});

  @override
  State<AppSettingScreen> createState() => _AppSettingScreenState();
}

class _AppSettingScreenState extends State<AppSettingScreen> {
  @override
  Widget build(BuildContext context) {
    var interval = Settings.getValue<double>('min_time_between_scans');

    return SettingsScreen(
      children: [
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
              onChange: (value) => setState(() => print(value)),
            ),
            const SwitchSettingsTile(
              title: 'Real-time Sync',
              subtitle: 'Automatically sync scans as they occur',
              settingKey: 'instant_sync',
              enabledLabel: 'Instant sync',
              disabledLabel: 'Manual sync',
            ),
          ],
        ),

        // REMOTE CONFIGURATION
        // -------------------------------------------------------------------
        const ExpandableSettingsTile(
          title: 'Remote Configuration',
          subtitle: 'Settings for remote configuration service',
          children: [
            TextInputSettingsTile(
              title: 'Device ID',
              settingKey: 'remote_config_id',
              helperText: 'Leave blank to auto-generate device identifier',
              initialValue: '',
            ),
            TextInputSettingsTile(
              title: 'Service URL',
              settingKey: 'remote_config_url',
              helperText: 'URL of the remote configuration service',
              initialValue: '',
            ),
          ],
        ),

        // EPCIS SETTINGS
        // -------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: const ExpandableSettingsTile(
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
                initialValue: 'https://webhook.site/0613bbc2-0873-465c-9f9b-32f8807ea822',
                helperText: 'API endpoint for EPCIS sync',
              ),
            ],
          ),
        ),

        // DATA EXPORT SETTINGS
        // -------------------------------------------------------------------
        const ExpandableSettingsTile(
          title: 'Data Export',
          subtitle: 'Configure data export methods',
          children: [
            // HTTP Export Settings
            SettingsGroup(
              title: 'HTTP Export',
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
                    ),
                    DropDownSettingsTile(
                      title: 'Request Method',
                      settingKey: 'http_method',
                      values: {
                        'GET': 'GET',
                        'POST': 'POST',
                      },
                      selected: 'POST',
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
              title: 'FTP Export',
              children: [
                SwitchSettingsTile(
                  title: 'Enable FTP Export',
                  settingKey: 'enable_ftp',
                  defaultValue: false,
                  childrenIfEnabled: [
                    TextInputSettingsTile(
                      title: 'Server Address',
                      settingKey: 'ftp_server',
                      initialValue: '',
                      helperText: 'FTP server hostname or IP address',
                    ),
                    TextInputSettingsTile(
                      title: 'Port',
                      settingKey: 'ftp_port',
                      initialValue: '21',
                      helperText: 'Default: 21 (FTP), 22 (SFTP)',
                    ),
                    TextInputSettingsTile(
                      title: 'Username',
                      settingKey: 'ftp_username',
                      initialValue: '',
                    ),
                    TextInputSettingsTile(
                      title: 'Password',
                      settingKey: 'ftp_password',
                      initialValue: '',
                      obscureText: true,
                    ),
                    TextInputSettingsTile(
                      title: 'Remote Directory',
                      settingKey: 'ftp_path',
                      initialValue: '',
                      helperText: 'Directory path on the FTP server',
                    ),
                    SwitchSettingsTile(
                      title: 'Use SFTP (Secure FTP)',
                      settingKey: 'use_sftp',
                      defaultValue: false,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
