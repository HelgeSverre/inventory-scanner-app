import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inventory_scanner/misc.dart';
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
            leading: Center(
              child: Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/scan_icon.svg',
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                    height: 32,
                    width: 32,
                    semanticsLabel: "Scanner Icon",
                  ),
                ),
              ),
            ),
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
              builder: (context) => const SessionHistoryScreen(),
            ),
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
      title: Text(
        session.name,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(),
      ),
      subtitle: Text(
        '${session.events.length} scans',
        style: Theme.of(context).textTheme.bodySmall!.copyWith(),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            session.startedAt.format("MMM d, yyyy"),
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(),
          ),
          Text(
            session.startedAt.diffForHumans(),
            style: Theme.of(context).textTheme.bodySmall!.copyWith(),
          ),
        ],
      ),
    );
  }
}

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
