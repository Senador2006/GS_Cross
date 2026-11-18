import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../state/alerts_provider.dart';
import '../../../state/occurrences_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../alerts/alerts_screen.dart';
import '../occurrences/occurrences_screen.dart';
import '../overview/overview_screen.dart';
import '../settings/settings_screen.dart';

/// Estrutura principal com navegação por abas.
/// Em telas largas (tablet/web) troca a barra inferior por NavigationRail.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final territory = context.read<TerritoryProvider>();
      if (territory.snapshot == null) {
        territory.load(
          offline: context.read<SettingsProvider>().prefs.simulateOffline,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingAlerts = context.select<AlertsProvider, int>(
      (a) => a.pendingCount,
    );
    final pendingSync = context.select<OccurrencesProvider, int>(
      (o) => o.pendingCount,
    );

    final destinations = [
      (
        icon: Icons.dashboard_outlined,
        selected: Icons.dashboard_rounded,
        label: 'Visão geral',
        badge: 0,
      ),
      (
        icon: Icons.notifications_outlined,
        selected: Icons.notifications_rounded,
        label: 'Alertas',
        badge: pendingAlerts,
      ),
      (
        icon: Icons.campaign_outlined,
        selected: Icons.campaign_rounded,
        label: 'Ocorrências',
        badge: pendingSync,
      ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings_rounded,
        label: 'Ajustes',
        badge: 0,
      ),
    ];

    Widget icon(IconData data, int badge, String label) => badge > 0
        ? Badge(
            label: Text('$badge'),
            child: Icon(data, semanticLabel: '$label, $badge pendentes'),
          )
        : Icon(data);

    const pages = [
      OverviewScreen(),
      AlertsScreen(),
      OccurrencesScreen(),
      SettingsScreen(),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = IndexedStack(index: _index, children: pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: icon(d.icon, d.badge, d.label),
                    selectedIcon: icon(d.selected, d.badge, d.label),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: icon(d.icon, d.badge, d.label),
              selectedIcon: icon(d.selected, d.badge, d.label),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
