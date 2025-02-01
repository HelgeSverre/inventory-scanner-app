import 'package:flutter/material.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scoped_model/scoped_model.dart';

class InventoryScanner extends StatefulWidget {
  const InventoryScanner({super.key});

  @override
  State<InventoryScanner> createState() => _InventoryScannerState();
}

class _InventoryScannerState extends State<InventoryScanner> {
  final MobileScannerController controller = MobileScannerController();
  bool isBottomSheetOpen = false;
  bool isFlashOn = false;

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    final model = ScopedModel.of<ScannerModel>(context);

    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null) {
        model.processScan(code, barcode.type.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        // If no active session, show session start screen
        if (!model.hasActiveSession) {
          return _buildSessionStartScreen(model);
        }

        return Scaffold(
          body: Stack(
            children: [
              // Camera Preview
              MobileScanner(
                controller: controller,
                onDetect: _onDetect,
              ),

              // Scan Overlay
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(seconds: 2),
                        curve: Curves.linear,
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Controls Overlay
              SafeArea(
                child: Column(
                  children: [
                    // Top bar with controls
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Session info
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.currentSession?.name ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Started: ${_formatTime(model.currentSession!.startedAt)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          // Controls
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    _showEndSessionDialog(context, model),
                              ),
                              IconButton(
                                icon: Icon(
                                  isFlashOn ? Icons.flash_on : Icons.flash_off,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isFlashOn = !isFlashOn;
                                    controller.toggleTorch();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Bottom sheet
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: isBottomSheetOpen
                          ? MediaQuery.of(context).size.height * 0.4
                          : 80,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          // Bottom sheet handle
                          GestureDetector(
                            onTap: () => setState(
                              () => isBottomSheetOpen = !isBottomSheetOpen,
                            ),
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  'Scans (${model.currentSession?.scans.length ?? 0})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (model.currentSession?.scans.isNotEmpty ??
                                    false)
                                  TextButton.icon(
                                    icon: const Icon(Icons.sync),
                                    label: const Text('Sync'),
                                    onPressed: () => model.syncSession(
                                      model.currentSession!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isBottomSheetOpen)
                            Expanded(
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount:
                                    model.currentSession?.scans.length ?? 0,
                                itemBuilder: (context, index) {
                                  final scan =
                                      model.currentSession!.scans[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                scan.productName ??
                                                    scan.barcode,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Type: ${scan.barcodeType}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatTime(scan.timestamp),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionStartScreen(ScannerModel model) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                'Start New Scanning Session',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Session Name (Optional)',
                  hintText: 'Enter session name or leave blank for default',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    model.startNewSession(value);
                  } else {
                    model.startNewSession();
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () => model.startNewSession(),
              ),
              if (model.sessions.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  'Previous Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: model.sessions.length,
                    itemBuilder: (context, index) {
                      final session = model.sessions[index];
                      return ListTile(
                        title: Text(session.name),
                        subtitle: Text(
                          '${session.scans.length} scans • ${_formatTime(session.startedAt)}',
                        ),
                        trailing: session.isSynced
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : const Icon(Icons.sync, color: Colors.orange),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEndSessionDialog(
      BuildContext context, ScannerModel model) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Session?'),
          content: Text(
            'End current scanning session "${model.currentSession?.name}"? '
            'This will save all scans and prepare them for sync.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('End Session'),
              onPressed: () {
                model.endCurrentSession();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
