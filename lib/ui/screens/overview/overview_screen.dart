import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/territory.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/alert.dart';
import '../../../data/models/indicator.dart';
import '../../../data/models/threshold.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../../state/view_status.dart';
import '../../widgets/common.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/semantic_style.dart';
import '../../widgets/state_views.dart';

/// Visão geral do território: status dos dashboards, impacto social e
/// alertas prioritários. Ponto de partida do fluxo
/// visão geral → dashboard → indicador → alerta.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final offline = context.select<SettingsProvider, bool>(
      (s) => s.prefs.simulateOffline,
    );

    Future<void> refresh() => territory.load(offline: offline);

    Widget body;
    switch (territory.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        body = const LoadingView(message: 'Coletando dados do território...');
      case ViewStatus.error:
        body = ErrorView(
          message: territory.errorMessage ?? 'Erro desconhecido.',
          onRetry: refresh,
        );
      case ViewStatus.empty:
        body = EmptyView(
          icon: Icons.inbox_outlined,
          title: 'Nenhum indicador disponível',
          message: 'As fontes não retornaram séries para o território.',
          actionLabel: 'Atualizar',
          onAction: refresh,
        );
      case ViewStatus.success:
        body = RefreshIndicator(
          onRefresh: refresh,
          child: const _OverviewContent(),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Radar Territorial'),
            Text(
              Territory.fullName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: territory.status == ViewStatus.loading ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent();

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final alerts = context.watch<AlertsProvider>();
    final settings = context.watch<SettingsProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : 2;

    final top = alerts.alerts
        .where((a) => alerts.statusFor(a.id) == DecisionStatus.pending)
        .take(3)
        .toList();

    return ResponsiveBody(
      child: ListView(
        padding: AppSpacing.page,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          DataStatusBanner(territory: territory),
          _AlertSummary(alerts: alerts),
          const SizedBox(height: AppSpacing.md),
          _ImpactCard(alerts: alerts),
          const SectionHeader(
            title: 'Dashboards territoriais',
            subtitle: 'Toque para ver histórico, tendência e previsões',
          ),
          // Wrap em vez de grid com altura fixa: os cards crescem com a
          // fonte do usuário sem estourar o layout.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = AppSpacing.md;
              final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final d in TerritoryDomain.values)
                    SizedBox(
                      width: w,
                      child: _DomainCard(
                        domain: d,
                        territory: territory,
                        alerts: alerts,
                        settings: settings,
                      ),
                    ),
                ],
              );
            },
          ),
          SectionHeader(
            title: 'Alertas aguardando avaliação',
            subtitle: top.isEmpty ? null : 'Mais graves primeiro',
          ),
          if (top.isEmpty)
            const AppCard(child: Text('Nenhum alerta pendente. Bom trabalho!'))
          else
            for (final a in top)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AlertTile(
                  alert: a,
                  status: alerts.statusFor(a.id),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.alert,
                    arguments: AlertArgs(a.id),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          const HumanDecisionNotice(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({required this.alerts});
  final AlertsProvider alerts;

  @override
  Widget build(BuildContext context) {
    int count(AlertSeverity s) =>
        alerts.alerts.where((a) => a.severity == s).length;
    return Row(
      children: [
        for (final s in AlertSeverity.values) ...[
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              semanticLabel: '${count(s)} alertas ${s.label}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    SemanticStyle.severityIcon(s),
                    color: SemanticStyle.severity(context, s),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${count(s)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          if (s != AlertSeverity.values.last)
            const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Indicador de benefício social em destaque (critério 8).
class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.alerts});
  final AlertsProvider alerts;

  @override
  Widget build(BuildContext context) {
    final impact = alerts.impact;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (impact == null) return const SizedBox.shrink();
    return AppCard(
      color: scheme.primaryContainer,
      onTap: () => Navigator.pushNamed(context, AppRoutes.impact),
      semanticLabel:
          'Benefício social: ${Fmt.number(impact.peopleCovered, decimals: 0)} '
          'pessoas em áreas com alertas tratados. '
          '${impact.alertsActioned} alertas com ação. Precisão média dos '
          'modelos ${Fmt.percent(impact.meanModelAccuracy)}. '
          'Toque para detalhes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Benefício social',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _Metric(
                value: Fmt.compact(impact.peopleCovered),
                label: 'pessoas em áreas\ncom alertas tratados',
              ),
              _Metric(
                value: '${impact.alertsActioned}/${impact.alertsTotal}',
                label: 'alertas com\nação humana',
              ),
              _Metric(
                value: Fmt.percent(impact.meanModelAccuracy),
                label: 'precisão média\ndos modelos',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(color: color),
        ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({
    required this.domain,
    required this.territory,
    required this.alerts,
    required this.settings,
  });

  final TerritoryDomain domain;
  final TerritoryProvider territory;
  final AlertsProvider alerts;
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SemanticStyle.domain(context, domain);
    final series = territory.seriesFor(domain);
    var worst = ThresholdLevel.normal;
    for (final s in series) {
      final v = territory.analysisById(s.id)?.current;
      if (v == null) continue;
      final l = settings
          .thresholdFor(s.id)
          .levelOf(v, s.definition.worseDirection);
      if (l.index > worst.index) worst = l;
    }
    final domainAlerts = alerts.alerts
        .where((a) => series.any((s) => s.id == a.indicatorId))
        .length;
    final levelColor = SemanticStyle.level(context, worst);

    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.dashboard,
        arguments: DashboardArgs(domain),
      ),
      semanticLabel:
          'Dashboard ${domain.label}: ${domain.subtitle}. '
          '${series.length} indicadores, $domainAlerts alertas. Situação '
          '${SemanticStyle.levelLabel(worst)}.',
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(SemanticStyle.domainIcon(domain), color: color),
              ),
              const Spacer(),
              StatusPill(
                label: SemanticStyle.levelLabel(worst),
                color: levelColor,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(domain.label, style: theme.textTheme.titleMedium),
          Text(
            '${domain.subtitle} · ${series.length} indicadores · '
            '$domainAlerts ${domainAlerts == 1 ? 'alerta' : 'alertas'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
