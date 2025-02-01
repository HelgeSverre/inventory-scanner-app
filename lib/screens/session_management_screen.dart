import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:share_plus/share_plus.dart';

class SessionManagementScreen extends StatelessWidget {
  const SessionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sessions'),
            actions: [
              IconButton(
                tooltip: "Sync all scan sessions",
                icon: const Icon(Icons.cloud_upload),
                onPressed: model.sessions.isEmpty
                    ? null
                    : () => _syncAllSessions(context, model),
              ),
              IconButton(
                tooltip: "Delete all stored scan  sessions",
                icon: const Icon(Icons.delete_sweep),
                onPressed: model.sessions.isEmpty
                    ? null
                    : () => _showClearAllDialog(context, model),
              ),
            ],
          ),
          body: model.sessions.isEmpty
              ? const Center(
                  child: Text('No sessions yet'),
                )
              : ListView.builder(
                  itemCount: model.sessions.length,
                  itemBuilder: (context, index) {
                    return _buildSessionTile(
                      context,
                      model.sessions[index],
                      model,
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildSessionTile(
    BuildContext context,
    ScanSession session,
    ScannerModel model,
  ) {
    return Dismissible(
      key: Key(session.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => model.deleteSession(session.id),
      child: ListTile(
        title: Text(session.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.events.length} scans (${session.barcodeCounts.length} unique) • ${_formatDateTime(session.startedAt)}',
            ),
            if (session.lastError != null)
              Text(
                'Error: ${session.lastError}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('Rename'),
              onTap: () => _showRenameDialog(context, session, model),
            ),
            PopupMenuItem(
              child: const Text('Export CSV'),
              onTap: () => _exportSession(context, session),
            ),
            PopupMenuItem(
              child: const Text('Share JSON'),
              onTap: () => _shareSession(context, session),
            ),
            if (!session.isSynced)
              PopupMenuItem(
                child: const Text('Sync Now'),
                onTap: () => model.syncSession(session),
              ),
            PopupMenuItem(
              child: const Text('Delete'),
              onTap: () => model.deleteSession(session.id),
            ),
          ],
        ),
        leading: Icon(
          session.isSynced ? Icons.check_circle : Icons.pending,
          color: session.isSynced ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    ScanSession session,
    ScannerModel model,
  ) async {
    final controller = TextEditingController(text: session.name);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Rename'),
            onPressed: () {
              model.renameSession(session.id, controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportSession(BuildContext context, ScanSession session) async {
    try {
      final file = await session.exportScanEventsToCsv();
      await Share.shareXFiles([XFile(file.path)], text: 'Scan Session Export');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _shareSession(BuildContext context, ScanSession session) async {
    final jsonStr = jsonEncode(session.toJson());
    await Share.share(jsonStr, subject: 'Scan Session Data');
  }

  Future<void> _syncAllSessions(
      BuildContext context, ScannerModel model) async {
    try {
      final count = model.sessions.length;
      int success = 0;

      for (final session in model.sessions) {
        if (!session.isSynced) {
          try {
            await model.syncSession(session);
            success++;
          } catch (e) {
            print('Failed to sync session ${session.id}: $e');
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced $success out of $count sessions')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _showClearAllDialog(
      BuildContext context, ScannerModel model) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Sessions?'),
        content: const Text(
          'This will permanently delete all scanning sessions. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Clear All'),
            onPressed: () {
              model.clearAllSessions();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month}-${dateTime.day} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
