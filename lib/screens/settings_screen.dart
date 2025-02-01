// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Settings'),
      ),
      body: ListView(
        children: [
          SettingsGroup(
            title: 'Scanning',
            children: [
              SliderSettingsTile(
                title: 'Minimum time between scans',
                settingKey: 'min_time_between_scans',
                defaultValue: 1000,
                min: 100,
                max: 5000,
                step: 100,
                leading: const Icon(Icons.timer),
                onChange: (value) {},
              ),
            ],
          ),
          SettingsGroup(
            title: 'HTTP Integration',
            children: [
              SwitchSettingsTile(
                title: 'Enable HTTP callback',
                settingKey: 'enable_http',
                defaultValue: false,
                onChange: (value) {},
              ),
              TextInputSettingsTile(
                title: 'Callback URL',
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
              SwitchSettingsTile(
                title: 'Instant sync',
                settingKey: 'instant_sync',
                defaultValue: false,
                onChange: (value) {},
              ),
            ],
          ),
          SettingsGroup(
            title: 'FTP Integration',
            children: [
              SwitchSettingsTile(
                title: 'Enable FTP export',
                settingKey: 'enable_ftp',
                defaultValue: false,
                onChange: (value) {},
              ),
              const TextInputSettingsTile(
                title: 'FTP Server',
                settingKey: 'ftp_server',
                initialValue: '',
              ),
              const TextInputSettingsTile(
                title: 'Port',
                settingKey: 'ftp_port',
                initialValue: '21',
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
              SwitchSettingsTile(
                title: 'Use SFTP',
                settingKey: 'use_sftp',
                defaultValue: true,
                onChange: (value) {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
