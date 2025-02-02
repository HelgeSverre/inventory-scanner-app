import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:inventory_scanner/models/scan_sessions.dart';
import 'package:inventory_scanner/screens/scanner.dart';
import 'package:inventory_scanner/screens/session_detail.dart';
import 'package:inventory_scanner/screens/session_history.dart';
import 'package:inventory_scanner/screens/settings.dart';
import 'package:scoped_model/scoped_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<ScannerModel>(
      builder: (context, child, model) {
        return Scaffold(
          // Simpler app bar with just essential info
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Settings.getValue<String>('device_name') ?? 'Unnamed Device',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  Settings.getValue<String>('device_location') ??
                      'No location set',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AppSettingScreen()),
                ),
              ),
            ],
          ),

          body: CustomScrollView(
            slivers: [
              // Active Session Banner (if exists)
              if (model.currentSession != null)
                SliverToBoxAdapter(
                  child: _ActiveSessionBanner(session: model.currentSession!),
                ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Quick Stats Row
                    _buildStatsRow(model),
                    const SizedBox(height: 24),

                    // Primary Actions
                    _buildPrimaryActions(context),
                    const SizedBox(height: 24),

                    // Recent Sessions Section
                    if (model.sessions.isNotEmpty) ...[
                      _buildRecentSessions(context, model),
                      const SizedBox(height: 24),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              _startNewScan(context);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start Scanning'),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(ScannerModel model) {
    final totalScans = model.sessions.fold<int>(
      0,
      (sum, session) => sum + session.events.length,
    );
    final uniqueItems = model.sessions.fold<Set<String>>(
      {},
      (items, session) => items..addAll(session.events.map((e) => e.barcode)),
    ).length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Scans',
            value: totalScans.toString(),
            icon: Icons.qr_code,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Unique Items',
            value: uniqueItems.toString(),
            icon: Icons.inventory_2,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const SessionHistoryScreen()),
          ),
          icon: const Icon(Icons.history),
          label: const Text('View Session History'),
        ),
      ],
    );
  }

  Widget _buildRecentSessions(BuildContext context, ScannerModel model) {
    final recentSessions = model.sessions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Sessions',
                style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SessionHistoryScreen(),
                ),
              ),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentSessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _SessionListTile(
              session: recentSessions[index],
              onTap: () {
                _viewSessionDetails(context, recentSessions[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _startNewScan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _viewSessionDetails(BuildContext context, ScanSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(session: session),
      ),
    );
  }
}

// New widget for active session banner
class _ActiveSessionBanner extends StatelessWidget {
  final ScanSession session;

  const _ActiveSessionBanner({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Session',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${session.events.length} scans'),
                Text(session.name),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _resumeSession(context, session),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _resumeSession(BuildContext context, ScanSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

// Simplified session list tile
class _SessionListTile extends StatelessWidget {
  final ScanSession session;
  final VoidCallback onTap;

  const _SessionListTile({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        session.isSynced ? Icons.check_circle : Icons.pending,
        color: session.isSynced ? Colors.green : Colors.orange,
      ),
      title: Text(session.name),
      subtitle: Text('${session.events.length} scans'),
      trailing: Text(
        _formatDateTime(session.startedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return ScopedModelDescendant<ScannerModel>(
//       builder: (context, child, model) {
//         return Scaffold(
//           appBar: AppBar(
//             leading: const Icon(Icons.timelapse_outlined),
//             // backgroundColor: Color(0xff011A99),
//             // centerTitle: true,
//             title: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   Settings.getValue<String>('device_name') ?? 'Unnamed Device',
//                   style: Theme.of(context).textTheme.titleMedium!.copyWith(
//                         height: 1,
//                       ),
//                 ),
//                 Text(
//                   Settings.getValue<String>('device_location') ??
//                       'No location set',
//                   style: Theme.of(context).textTheme.titleSmall!.copyWith(
//                         fontWeight: FontWeight.normal,
//                         height: 1,
//                       ),
//                 ),
//               ],
//             ),
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.settings),
//                 onPressed: () => Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const AppSettingScreen(),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           body: SingleChildScrollView(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   // Quick Stats Cards
//                   _buildStatsSection(context, model),
//                   const SizedBox(height: 24),
//
//                   // Active/Last Session Card
//                   if (model.currentSession != null || model.sessions.isNotEmpty)
//                     _buildLastSessionCard(context, model),
//
//                   const SizedBox(height: 24),
//
//                   // Action Buttons
//                   _buildActionButtons(context, model),
//
//                   const SizedBox(height: 24),
//
//                   // Recent Activity
//                   if (model.sessions.isNotEmpty)
//                     _buildRecentActivity(context, model),
//                   const SizedBox(height: 48),
//                 ],
//               ),
//             ),
//           ),
//           floatingActionButton: FloatingActionButton.extended(
//             onPressed: () => _startNewScan(context),
//             icon: const Icon(Icons.qr_code_scanner),
//             label: const Text('New Scan'),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildStatsSection(BuildContext context, ScannerModel model) {
//     // Calculate some basic stats
//     final totalScans = model.sessions.fold<int>(
//       0,
//       (sum, session) => sum + session.events.length,
//     );
//     final totalSessions = model.sessions.length;
//     final uniqueItems = model.sessions.fold<Set<String>>(
//       {},
//       (items, session) => items..addAll(session.events.map((e) => e.barcode)),
//     ).length;
//
//     return Row(
//       children: [
//         Expanded(
//           child: _StatCard(
//             title: 'Total Scans',
//             value: totalScans.toString(),
//             icon: Icons.qr_code,
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: _StatCard(
//             title: 'Sessions',
//             value: totalSessions.toString(),
//             icon: Icons.history,
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: _StatCard(
//             title: 'Items',
//             value: uniqueItems.toString(),
//             icon: Icons.inventory_2,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLastSessionCard(BuildContext context, ScannerModel model) {
//     final session = model.currentSession ?? model.sessions.first;
//     final isActive = model.currentSession != null;
//
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   isActive ? Icons.pending_actions : Icons.inventory,
//                   color: isActive ? Colors.green : null,
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     isActive ? 'Active Session' : 'Last Session',
//                     style: Theme.of(context).textTheme.titleMedium,
//                   ),
//                 ),
//                 if (isActive)
//                   const Chip(
//                     label: Text('In Progress'),
//                     backgroundColor: Colors.green,
//                     labelStyle: TextStyle(color: Colors.white),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               session.name,
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//             const SizedBox(height: 4),
//             Text(
//               'Started: ${_formatDateTime(session.startedAt)}',
//               style: Theme.of(context).textTheme.bodySmall,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               '${session.events.length} scans • ${session.barcodeCounts.length} unique items',
//             ),
//             const SizedBox(height: 16),
//             Row(
//               children: [
//                 if (isActive)
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       icon: const Icon(Icons.play_arrow),
//                       label: const Text('Resume Scanning'),
//                       onPressed: () => _resumeSession(context, session),
//                     ),
//                   )
//                 else
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       icon: const Icon(Icons.remove_red_eye),
//                       label: const Text('View Details'),
//                       onPressed: () => _viewSessionDetails(context, session),
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildActionButtons(BuildContext context, ScannerModel model) {
//     return Row(
//       children: [
//         Expanded(
//           child: _ActionButton(
//             icon: Icons.history,
//             label: 'Session History',
//             onTap: () => Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => const SessionHistoryScreen(),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: _ActionButton(
//             icon: Icons.cloud_upload,
//             label: 'Sync All',
//             onTap: model.sessions.isEmpty
//                 ? null
//                 : () => _syncAllSessions(context, model),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildRecentActivity(BuildContext context, ScannerModel model) {
//     final recentSessions = model.sessions.take(3).toList();
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'Recent Activity',
//               style: Theme.of(context).textTheme.titleMedium,
//             ),
//             TextButton(
//               onPressed: () => Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const SessionHistoryScreen(),
//                 ),
//               ),
//               child: const Text('View All'),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         ...recentSessions.map(
//           (session) => InkWell(
//             onTap: () => _viewSessionDetails(context, session),
//             child: _RecentSessionTile(session: session),
//           ),
//         ),
//       ],
//     );
//   }
//
//   void _startNewScan(BuildContext context) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const ScannerScreen(),
//         fullscreenDialog: true,
//       ),
//     );
//   }
//
//   void _resumeSession(BuildContext context, ScanSession session) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const ScannerScreen(),
//         fullscreenDialog: true,
//       ),
//     );
//   }
//
//   void _viewSessionDetails(BuildContext context, ScanSession session) {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) => SessionDetailsScreen(session: session),
//       ),
//     );
//   }
//
//   Future<void> _syncAllSessions(
//       BuildContext context, ScannerModel model) async {
//     try {
//       final count = model.sessions.length;
//       int success = 0;
//
//       for (final session in model.sessions) {
//         if (!session.isSynced) {
//           try {
//             await model.syncSession(session);
//             success++;
//           } catch (e) {
//             print('Failed to sync session ${session.id}: $e');
//           }
//         }
//       }
//
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Synced $success out of $count sessions')),
//         );
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Sync failed: $e')),
//         );
//       }
//     }
//   }
//
//   String _formatDateTime(DateTime dateTime) {
//     return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
//         '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
//   }
// }

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
