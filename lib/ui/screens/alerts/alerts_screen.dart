import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/alert.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../../state/view_status.dart';
import '../../widgets/common.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/semantic_style.dart';
import '../../widgets/state_views.dart';

enum _StatusFilter { pending, decided, all }

/// Lista de alertas com filtros (estado local) sobre o estado global.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final Set<AlertSeverity> _severities = AlertSeverity.values.toSet();
  _StatusFilter _status = _StatusFilter.pending;

  @override
  Widget build(BuildContext context) {
    final alertsState = context.watch<AlertsProvider>();
    final territory = context.watch<TerritoryProvider>();
    final offline = context.select<SettingsProvider, bool>(
      (s) => s.prefs.simulateOffline,
    );

    Widget body;
    switch (alertsState.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        body = const LoadingView(message: 'Analisando indicadores...');
      case ViewStatus.error:
        body = ErrorView(
          message: alertsState.errorMessage ?? 'Erro desconhecido.',
          onRetry: () => territory.load(offline: offline),
        );
      case ViewStatus.empty:
        body = const EmptyView(
          icon: Icons.notifications_off_outlined,
          title: 'Nenhum alerta no momento',
          message:
              'Todos os indicadores estão dentro dos limiares e sem '
              'anomalias ou tendências preocupantes.',
        );
      case ViewStatus.success:
        final filtered = alertsState.alerts.where((a) {
          if (!_severities.contains(a.severity)) return false;
          final decided = alertsState.decisionFor(a.id) != null;
          return switch (_status) {
            _StatusFilter.pending => !decided,
            _StatusFilter.decided => decided,
            _StatusFilter.all => true,
          };
        }).toList();
        body = RefreshIndicator(
          onRefresh: () => territory.load(offline: offline),
          child: ResponsiveBody(
            child: ListView(
              padding: AppSpacing.page,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const HumanDecisionNotice(compact: true),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<_StatusFilter>(
                  segments: [
                    ButtonSegment(
                      value: _StatusFilter.pending,
                      label: Text('Pendentes (${alertsState.pendingCount})'),
                    ),
                    const ButtonSegment(
                      value: _StatusFilter.decided,
                      label: Text('Avaliados'),
                    ),
                    const ButtonSegment(
                      value: _StatusFilter.all,
                      label: Text('Todos'),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (v) => setState(() => _status = v.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final s in AlertSeverity.values)
                      FilterChip(
                        avatar: Icon(
                          SemanticStyle.severityIcon(s),
                          size: 18,
                          color: SemanticStyle.severity(context, s),
                        ),
                        label: Text(s.label),
                        selected: _severities.contains(s),
                        onSelected: (on) => setState(
                          () => on ? _severities.add(s) : _severities.remove(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xl),
                    child: EmptyView(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nenhum alerta com estes filtros',
                      message: 'Altere os filtros para ver outros alertas.',
                    ),
                  )
                else
                  for (final a in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AlertTile(
                        alert: a,
                        status: alertsState.statusFor(a.id),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.alert,
                          arguments: AlertArgs(a.id),
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas preditivos')),
      body: body,
    );
  }
}
