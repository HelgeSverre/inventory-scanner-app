import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_scanner/exporter.dart';
import 'package:inventory_scanner/misc.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:scoped_model/scoped_model.dart';

class SessionDetailsScreen extends StatefulWidget {
  final ScanSession session;

  const SessionDetailsScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.session.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showRenameDialog(context, model),
                ),
                IconButton(
                  icon: Icon(
                    widget.session.isSynced
                        ? Icons.cloud_done
                        : Icons.cloud_upload,
                    color:
                        widget.session.isSynced ? Colors.green : Colors.orange,
                  ),
                  onPressed: widget.session.isSynced
                      ? null
                      : () => model.syncSession(widget.session),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'save_csv',
                      child: Text('Export CSV file'),
                    ),
                    const PopupMenuItem(
                      value: 'save_json',
                      child: Text('Export JSON file'),
                    ),
                    const PopupMenuItem(
                      value: 'share_csv',
                      child: Text('Share CSV'),
                    ),
                    const PopupMenuItem(
                      value: 'share_json',
                      child: Text('Share JSON'),
                    ),
                    const PopupMenuItem(
                      value: 'upload_ftp',
                      child: Text('Upload to FTP'),
                    ),
                    const PopupMenuItem(
                      value: 'upload_http',
                      child: Text('Upload to HTTP'),
                    ),
                    const PopupMenuItem(
                      value: 'upload_epcis',
                      child: Text('Upload to EPCIS'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  onSelected: (value) => _handleMenuAction(
                    context,
                    value,
                    model,
                  ),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Summary'),
                  Tab(text: 'Scan Log'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildSummaryTab(),
                _buildScanLogTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildStatsCard(),
        const SizedBox(height: 16),
        if (widget.session.barcodeCounts.isNotEmpty) _buildMostScannedCard()
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Started', _formatDateTime(widget.session.startedAt)),
            _buildInfoRow(
              'Finished',
              widget.session.finishedAt?.format("yyyy-MM-dd HH:mm:ss"),
            ),
            _buildInfoRow('Duration', _calculateDuration()),
            _buildInfoRow('Session ID', widget.session.id),
            if (widget.session.lastSyncAttempt != null)
              _buildInfoRow(
                'Last Sync',
                _formatDateTime(widget.session.lastSyncAttempt!),
              ),
            if (widget.session.lastError != null)
              _buildInfoBox(
                'Last Sync Error',
                widget.session.lastError,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Total Scans', widget.session.events.length.toString()),
            _buildInfoRow(
              'Unique Items',
              widget.session.barcodeCounts.length.toString(),
            ),
            _buildInfoRow(
              'Average Scans/Item',
              (widget.session.events.length /
                      widget.session.barcodeCounts.length)
                  .toStringAsFixed(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMostScannedCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most Scanned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.session.sortedBarcodeCounts.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(entry.key),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value} scans',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanLogTab() {
    var events = widget.session.events;

    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No barcodes scanned yet.'),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final offset = events.length - 1 - index;
        final event = events[offset];

        return ListTile(
          contentPadding: EdgeInsets.all(4),
          tileColor: Theme.of(context).cardColor,
          minLeadingWidth: 80,
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.timestamp.format("yyyy-MM-dd"),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                event.timestamp.format("HH:mm"),
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          title: Text(event.barcode),
          subtitle: Text(event.barcodeFormat),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: event.barcode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Barcode copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white.withOpacity(0.2),
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                value ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: "monospace",
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    return dateTime == null ? 'N/A' : dateTime.format("yyyy-MM-dd HH:mm:ss");
  }

  String _calculateDuration() {
    final end = widget.session.finishedAt ?? DateTime.now();
    final duration = end.difference(widget.session.startedAt);

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, ScannerModel model) async {
    final controller = TextEditingController(text: widget.session.name);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Rename'),
            onPressed: () {
              model.renameSession(
                widget.session.id,
                controller.text.trim(),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    ScannerModel model,
  ) async {
    try {
      switch (action) {
        case 'save_csv':
          if (await DataExporter.saveCsvToDisk(widget.session)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Successfully saved CSV file')),
            );
          }
          break;

        case 'save_json':
          if (await DataExporter.saveJsonToDisk(widget.session)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Successfully saved JSON file')),
            );
          }
          break;
        case 'share_csv':
          await DataExporter.shareCsv(widget.session);
          break;
        case 'share_json':
          await DataExporter.shareJson(widget.session);
          break;
        case 'upload_ftp':
          await DataExporter.uploadToFtp(widget.session);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully uploaded to FTP')),
          );
          break;
        case 'upload_http':
          await DataExporter.uploadToHttp(widget.session);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully uploaded to server')),
          );
          break;
        case 'upload_epcis':
          await DataExporter.uploadToEpcis(widget.session);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully uploaded to EPCIS')),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Export failed: \n$e",
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
