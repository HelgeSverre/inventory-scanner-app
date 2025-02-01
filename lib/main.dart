import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:inventory_scanner/screens/home_screen.dart';
import 'package:scoped_model/scoped_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings
  await Settings.init(
    cacheProvider: SharePreferenceCache(),
  );

  // Initialize scanner model
  final model = ScannerModel();
  await model.init();

  runApp(
    ScopedModel<ScannerModel>(
      model: model,
      child: const ScannerApp(),
    ),
  );
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
