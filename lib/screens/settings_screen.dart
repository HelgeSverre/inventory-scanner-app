// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // SCANNING
          // -------------------------------------------------------------------
          const ExpandableSettingsTile(
            title: 'Scanning',
            subtitle: "Determines the scanning behaviour of the app",
            children: [
              SliderSettingsTile(
                title: 'Minimum time between scans',
                settingKey: 'min_time_between_scans',
                defaultValue: 1000.0,
                min: 100.0,
                max: 5000.0,
                step: 100.0,
                leading: Icon(Icons.timer),
              ),
              CheckboxSettingsTile(
                title: "Barcode Formats",
                settingKey: "accepted_barcode_formats",
              ),
            ],
          ),

          // DEVICE IDENTITY
          // -------------------------------------------------------------------
          ExpandableSettingsTile(
            title: 'Device Identity',
            subtitle: "Information about this scanner device",
            children: [
              TextInputSettingsTile(
                title: 'Device Name',
                settingKey: 'device_name',
                initialValue: '',
                helperText: "Optional: Name of scanner device",
              ),
              const TextInputSettingsTile(
                title: 'Location',
                settingKey: 'device_location',
                initialValue: '',
                helperText: 'Optional: Physical location of this scanner',
              ),
            ],
          ),

          // INTEGRATION
          // -------------------------------------------------------------------
          ExpandableSettingsTile(
            title: 'HTTP Integration',
            subtitle: "If and how the app should send data via HTTP",
            children: [
              SettingsGroup(
                title: 'Enable HTTP callback',
                children: [
                  TextInputSettingsTile(
                    title: 'URL',
                    settingKey: 'http_url',
                    initialValue: '',
                    validator: (String? url) =>
                        url?.isEmpty ?? true ? 'URL cannot be empty' : null,
                  ),
                  const DropDownSettingsTile(
                    title: 'HTTP Method',
                    settingKey: 'http_method',
                    values: {
                      'GET': 'GET',
                      'POST': 'POST',
                    },
                    selected: 'POST',
                  ),
                  const TextInputSettingsTile(
                    title: 'Username',
                    settingKey: 'http_username',
                    initialValue: '',
                  ),
                  const TextInputSettingsTile(
                    title: 'Password',
                    settingKey: 'http_password',
                    initialValue: '',
                    obscureText: true,
                  ),
                  const SwitchSettingsTile(
                    title: 'Instant sync',
                    settingKey: 'instant_sync',
                    defaultValue: false,
                  ),
                ],
              ),
            ],
          ),

          // INTEGRATION
          // -------------------------------------------------------------------
          const ExpandableSettingsTile(
            title: 'FTP Integration',
            subtitle: "If and how the app should send data via FTP transfers.",
            children: [
              SwitchSettingsTile(
                title: 'Enable FTP export',
                settingKey: 'enable_ftp',
                defaultValue: false,
                childrenIfEnabled: [
                  TextInputSettingsTile(
                    title: 'FTP Server',
                    settingKey: 'ftp_server',
                    initialValue: '',
                  ),
                  TextInputSettingsTile(
                    title: 'Port',
                    settingKey: 'ftp_port',
                    initialValue: '21',
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
                  SwitchSettingsTile(
                    title: 'Use SFTP',
                    settingKey: 'use_sftp',
                    defaultValue: true,
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
