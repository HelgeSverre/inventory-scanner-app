import 'package:flutter/material.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:inventory_scanner/screens/session_detail.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:share_plus/share_plus.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  String _searchQuery = '';
  bool _showOnlyUnsynced = false;
  final _selectedSessions = <String>{};

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        final filteredSessions = _filterSessions(model.sessions);

        return Scaffold(
          appBar: AppBar(
            title: _selectedSessions.isEmpty
                ? const Text('Session History')
                : Text('${_selectedSessions.length} selected'),
            actions: _buildAppBarActions(context, model, filteredSessions),
          ),
          body: Column(
            children: [
              // Search and Filter Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        hintText: 'Search sessions...',
                        leading: const Icon(Icons.search),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilterChip(
                      label: const Text('Unsynced'),
                      selected: _showOnlyUnsynced,
                      onSelected: (value) {
                        setState(() => _showOnlyUnsynced = value);
                      },
                    ),
                  ],
                ),
              ),

              // Sessions List
              Expanded(
                child: filteredSessions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = filteredSessions[index];
                          return _SessionListItem(
                            session: session,
                            isSelected: _selectedSessions.contains(session.id),
                            onToggleSelect: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSessions.add(session.id);
                                } else {
                                  _selectedSessions.remove(session.id);
                                }
                              });
                            },
                            onTap: () => _showSessionDetails(context, session),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    ScannerModel model,
    List<ScanSession> sessions,
  ) {
    if (_selectedSessions.isEmpty) {
      return [
        if (sessions.isNotEmpty) ...[
          IconButton(
            tooltip: 'Select all',
            icon: const Icon(Icons.select_all),
            onPressed: () {
              setState(() {
                _selectedSessions.addAll(sessions.map((s) => s.id));
              });
            },
          ),
          IconButton(
            tooltip: 'Sync all',
            icon: const Icon(Icons.cloud_upload),
            onPressed: () => _syncSessions(context, model, sessions),
          ),
        ],
      ];
    }

    return [
      TextButton.icon(
        icon: const Icon(Icons.sync),
        label: const Text('Sync'),
        onPressed: () {
          _syncSessions(
            context,
            model,
            sessions.where((s) => _selectedSessions.contains(s.id)).toList(),
          );
        },
      ),
      TextButton.icon(
        icon: const Icon(Icons.share),
        label: const Text('Export'),
        onPressed: () => _exportSessions(
          context,
          sessions.where((s) => _selectedSessions.contains(s.id)).toList(),
        ),
      ),
      TextButton.icon(
        icon: const Icon(Icons.delete),
        label: const Text('Delete'),
        onPressed: () => _confirmDeleteSessions(context, model),
      ),
    ];
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty || _showOnlyUnsynced) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No sessions match your filters',
              style: TextStyle(fontSize: 16),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _showOnlyUnsynced = false;
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No scanning sessions yet',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  List<ScanSession> _filterSessions(List<ScanSession> sessions) {
    return sessions.where((session) {
      if (_showOnlyUnsynced && session.isSynced) return false;
      if (_searchQuery.isEmpty) return true;

      return session.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          session.id.contains(_searchQuery);
    }).toList();
  }

  Future<void> _syncSessions(
    BuildContext context,
    ScannerModel model,
    List<ScanSession> sessions,
  ) async {
    var count = sessions.length;
    var success = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final session in sessions) {
        if (!session.isSynced) {
          try {
            await model.syncSession(session);
            success++;
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to sync session ${session.id}: $e',
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${success} items out of ${count}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss progress indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'CSV export failed: $e',
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

  Future<void> _exportSessions(
    BuildContext context,
    List<ScanSession> sessions,
  ) async {
    try {
      final files = await Future.wait(
        sessions.map((s) => s.exportScanEventsToCsv()),
      );
      await Share.shareXFiles(
        files.map((f) => XFile(f.path)).toList(),
        text: 'Scan Session Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: $e',
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

  Future<void> _confirmDeleteSessions(
    BuildContext context,
    ScannerModel model,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sessions?'),
        content: Text(
          'Are you sure you want to delete ${_selectedSessions.length} sessions? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedSessions) {
        await model.deleteSession(id);
      }
      setState(() => _selectedSessions.clear());
    }
  }

  void _showSessionDetails(BuildContext context, ScanSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(session: session),
      ),
    );
  }
}

class _SessionListItem extends StatelessWidget {
  final ScanSession session;
  final bool isSelected;
  final ValueChanged<bool> onToggleSelect;
  final VoidCallback onTap;

  const _SessionListItem({
    required this.session,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (value) => onToggleSelect(value ?? false),
      ),
      title: Text(session.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${session.events.length} scans • ${session.barcodeCounts.length} unique',
          ),
          if (session.lastError != null)
            Text(
              'Error: ${session.lastError}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
      trailing: Icon(
        session.isSynced ? Icons.cloud_done : Icons.cloud_upload,
        color: session.isSynced ? Colors.green : Colors.orange,
      ),
      onTap: onTap,
    );
  }
}
