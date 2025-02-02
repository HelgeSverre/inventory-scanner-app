import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scoped_model/scoped_model.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isFlashOn = false;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraController.start();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      _cameraController.stop();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final model = ScopedModel.of<ScannerModel>(context);
    for (final barcode in capture.barcodes) {
      var accepted = await model.processScan(barcode);

      if (accepted) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        if (!model.hasActiveSession) {
          return _SessionStartScreen(
            onStartSession: (name) {
              model.startNewSession(name);
            },
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              // Camera View
              if (_isCameraInitialized)
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onDetect,
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Scanner UI Overlay
              SafeArea(
                child: Column(
                  children: [
                    // Top Bar
                    _buildTopBar(model),

                    // Scanning Area
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          _buildScannerOverlay(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),

                    // Bottom Area
                    _ScannedItemsSheet(model: model),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ScannerModel model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.currentSession?.name ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${model.currentSession?.events.length ?? 0} scans',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isFlashOn = !_isFlashOn;
                _cameraController.toggleTorch();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _showEndSessionDialog(context, model),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Scanning line animation
              AnimatedPositioned(
                duration: const Duration(seconds: 1),
                top: 0,
                left: 0,
                right: 0,
                curve: Curves.easeInOut,
                child: Container(
                  height: 2,
                  color: Colors.red.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEndSessionDialog(BuildContext context, ScannerModel model) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('End session "${model.currentSession?.name}"?'),
            const SizedBox(height: 8),
            Text(
              '${model.currentSession?.events.length ?? 0} items scanned',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('End Session'),
            onPressed: () {
              model.endCurrentSession();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to home
            },
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    super.dispose();
  }
}

class _SessionStartScreen extends StatefulWidget {
  final Function(String?) onStartSession;

  const _SessionStartScreen({required this.onStartSession});

  @override
  State<_SessionStartScreen> createState() => _SessionStartScreenState();
}

class _SessionStartScreenState extends State<_SessionStartScreen> {
  final _sessionNameController = TextEditingController();

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Session'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _sessionNameController,
              decoration: const InputDecoration(
                labelText: 'Session Name',
                hintText: 'Enter a name for this scanning session',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _startSession(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
              onPressed: _startSession,
            ),
          ],
        ),
      ),
    );
  }

  void _startSession() {
    final name = _sessionNameController.text.trim();
    widget.onStartSession(name.isEmpty ? null : name);
  }
}

class _ScannedItemsSheet extends StatelessWidget {
  final ScannerModel model;

  const _ScannedItemsSheet({required this.model});

  @override
  Widget build(BuildContext context) {
    final items = model.currentSession?.barcodeCounts ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Scanned Items (${items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (items.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                    onPressed: model.undoLastScan,
                  ),
              ],
            ),
          ),
          // List
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final entry = items[index];
                return _ScannedItemTile(
                  barcode: entry.key,
                  count: entry.value,
                  model: model,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannedItemTile extends StatelessWidget {
  final String barcode;
  final int count;
  final ScannerModel model;

  const _ScannedItemTile({
    required this.barcode,
    required this.count,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(barcode),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => model.removeBarcode(barcode),
      child: Card(
        child: ListTile(
          title: Text(
            barcode,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            model.currentSession!.events
                .firstWhere((e) => e.barcode == barcode)
                .barcodeFormat
                .toUpperCase(),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: count > 1
                    ? () => model.removeLastEventForBarcode(barcode)
                    : null,
              ),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => model.incrementScanCountForBarcode(barcode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
