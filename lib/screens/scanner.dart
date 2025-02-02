import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:inventory_scanner/widgets/panel.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scoped_model/scoped_model.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final _cameraController = MobileScannerController();
  final panelController = SlidingUpPanelController();
  final GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();

  bool _isFlashOn = false;
  bool _isCameraInitialized = false;
  bool manuallyCollapsedPanel = false;
  SlidingUpPanelStatus currentPanelStatus = SlidingUpPanelStatus.collapsed;

  late final AnimationController flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final colorTween = ColorTween(
    begin: Colors.transparent,
    end: Colors.white.withOpacity(0.3),
  ).animate(
    CurvedAnimation(
      parent: flashController,
      curve: Curves.easeOut,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    panelController.addListener(() {
      setState(() {
        currentPanelStatus = panelController.status;
      });
    });
  }

  @override
  void dispose() {
    flashController.dispose();
    panelController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraController.start();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final model = ScopedModel.of<ScannerModel>(context);
    for (final barcode in capture.barcodes) {
      var accepted = await model.processScan(barcode);
      if (accepted) {
        HapticFeedback.mediumImpact();

        listKey.currentState
            ?.insertItem(0, duration: const Duration(milliseconds: 250));

        // If this is the first scan, anchor the panel
        if (model.currentSession?.barcodeCounts.length == 1) {
          panelController.anchor();
        }
        // If continuing to scan and panel wasn't manually collapsed, expand it
        else if (!manuallyCollapsedPanel &&
            model.currentSession?.barcodeCounts.length != null) {
          panelController.expand();
        }

        // Trigger screen flash
        flashController.forward().then((_) {
          Future.delayed(
            const Duration(milliseconds: 250),
            () => flashController.reverse(),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        var scanCounts = model.currentSession?.barcodeCounts;

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

              // Scanner UI Overlay with scanning rectangle
              _buildScanAreaOverlay(),

              // Camera Controls (flash, switch camera)
              _buildCameraControls(),

              // Sliding Panel
              Positioned(
                // duration: const Duration(milliseconds: 200),
                // curve: Curves.easeInOut,
                right: 0,
                left: 0,
                top: 300,
                bottom: currentPanelStatus == SlidingUpPanelStatus.collapsed
                    ? 25
                    : 0,
                child: SlidingUpPanelWidget(
                  anchor: 0.5,
                  panelController: panelController,
                  controlHeight: kBottomNavigationBarHeight,
                  enableOnTap: false,
                  onTap: () => _handlePanelTap(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Panel Header
                      Container(
                        height: kBottomNavigationBarHeight,
                        padding: const EdgeInsets.only(left: 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scanned Items (${(model.currentSession?.barcodeCounts ?? []).length})',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    model.currentSession?.name ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Chevron
                            Container(
                              padding: const EdgeInsets.all(8),
                              height: kBottomNavigationBarHeight,
                              width: kBottomNavigationBarHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: AnimatedRotation(
                                turns: currentPanelStatus ==
                                        SlidingUpPanelStatus.collapsed
                                    ? 0.75
                                    : 0.25,
                                duration: const Duration(milliseconds: 250),
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _handlePanelTap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Container(
                        height: 1,
                        color: Colors.grey[400],
                      ),

                      // Scanned Items List
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: scanCounts?.length ?? 0,
                            itemBuilder: (context, index) {
                              var entry =
                                  model.currentSession!.barcodeCounts[index];

                              return Card(
                                child: Dismissible(
                                  key: Key(entry.key),
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    child: const Icon(Icons.delete,
                                        color: Colors.white),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) {
                                    model.removeBarcode(entry.key);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        // Barcode info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                entry.key,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                model.currentSession!.events
                                                    .firstWhere((e) =>
                                                        e.barcode == entry.key)
                                                    .barcodeFormat
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Count controls
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
                                              onPressed: entry.value > 1
                                                  ? () => model
                                                      .removeLastEventForBarcode(
                                                          entry.key)
                                                  : null,
                                              color: entry.value > 1
                                                  ? Colors.blue
                                                  : Colors.grey[400],
                                            ),
                                            SizedBox(
                                              width: 32,
                                              child: Text(
                                                entry.value.toString(),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.add_circle_outline),
                                              onPressed: () => model
                                                  .incrementScanCountForBarcode(
                                                      entry.key),
                                              color: Colors.blue,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScanAreaOverlay() {
    double ratio = 1.5;
    double width = MediaQuery.of(context).size.shortestSide * .8;
    double height = width / ratio;

    return AnimatedAlign(
      curve: Curves.easeInOutCubicEmphasized,
      duration: const Duration(milliseconds: 300),
      alignment: currentPanelStatus == SlidingUpPanelStatus.collapsed
          ? Alignment.center
          : const Alignment(0.0, -0.5),
      child: AnimatedBuilder(
        animation: flashController,
        builder: (context, _) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colorTween.value,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Column(
          children: [
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
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: () => _cameraController.switchCamera(),
            ),
            IconButton(
              icon: const Icon(Icons.code, color: Colors.red),
              onPressed: () {
                ScopedModel.of<ScannerModel>(context).processScan(
                  const Barcode(
                    format: BarcodeFormat.ean13,
                    rawValue: '7071089087940',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handlePanelTap() {
    setState(() {
      manuallyCollapsedPanel = true;

      return currentPanelStatus == SlidingUpPanelStatus.collapsed
          ? panelController.anchor()
          : panelController.collapse();
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
  void initState() {
    super.initState();
    _sessionNameController.text = ScannerModel.defaultSessionName();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  void _startSession() {
    final name = _sessionNameController.text.trim();
    widget.onStartSession(name.isEmpty ? null : name);
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
}
