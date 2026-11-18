import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/indicator.dart';
import '../../../domain/analytics/statistics.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../../state/view_status.dart';
import '../../widgets/common.dart';
import '../../widgets/forecast_chart.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/semantic_style.dart';
import '../../widgets/state_views.dart';

/// Dashboard de um domínio (Recursos, Clima, Resíduos ou Serviços).
///
/// Estado LOCAL: período exibido e indicador em destaque no gráfico.
/// Estado GLOBAL (Provider): séries, análises, limiares e alertas.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.domain});
  final TerritoryDomain domain;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _period = 30;
  String? _focusId;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final alerts = context.watch<AlertsProvider>();
    final domain = widget.domain;
    final series = territory.seriesFor(domain);
    final color = SemanticStyle.domain(context, domain);

    Widget body;
    if (territory.status == ViewStatus.loading ||
        territory.status == ViewStatus.initial) {
      body = const LoadingView();
    } else if (territory.status == ViewStatus.error) {
      body = ErrorView(
        message: territory.errorMessage ?? '',
        onRetry: () => territory.load(offline: settings.prefs.simulateOffline),
      );
    } else if (series.isEmpty) {
      body = const EmptyView(
        icon: Icons.inbox_outlined,
        title: 'Sem dados neste dashboard',
        message: 'Nenhuma série foi recebida para este domínio.',
      );
    } else {
      final focus = series.firstWhere(
        (s) => s.id == _focusId,
        orElse: () => series.first,
      );
      final focusAnalysis = territory.analysisById(focus.id)!;
      final domainAlerts = alerts.alerts
          .where((a) => series.any((s) => s.id == a.indicatorId))
          .toList();
      final width = MediaQuery.sizeOf(context).width;
      final columns = width >= 900 ? 4 : 2;

      body = RefreshIndicator(
        onRefresh: () =>
            territory.load(offline: settings.prefs.simulateOffline),
        child: ResponsiveBody(
          child: ListView(
            padding: AppSpacing.page,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DataStatusBanner(territory: territory),
              Text(
                series.first.origin.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SectionHeader(title: 'Indicadores agora'),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = AppSpacing.md;
                  final w = (c.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final s in series)
                        SizedBox(
                          width: w,
                          child: KpiCard(
                            series: s,
                            analysis: territory.analysisById(s.id)!,
                            threshold: settings.thresholdFor(s.id),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.indicator,
                              arguments: IndicatorArgs(s.id),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SectionHeader(
                title: 'Histórico e previsão',
                subtitle: 'Escolha o indicador e o período',
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final s in series)
                          ChoiceChip(
                            label: Text(s.definition.shortName),
                            selected: s.id == focus.id,
                            onSelected: (_) => setState(() => _focusId = s.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7 d')),
                        ButtonSegment(value: 14, label: Text('14 d')),
                        ButtonSegment(value: 30, label: Text('30 d')),
                        ButtonSegment(value: 60, label: Text('60 d')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (v) =>
                          setState(() => _period = v.first),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${focus.definition.name} (${focus.definition.unit})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ForecastChart(
                      series: focus,
                      analysis: focusAnalysis,
                      threshold: settings.thresholdFor(focus.id),
                      historyDays: _period,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ConfidenceMeter(score: focusAnalysis.confidenceScore),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.indicator,
                          arguments: IndicatorArgs(focus.id),
                        ),
                        icon: const Icon(Icons.insights_rounded),
                        label: const Text('Ver análise completa'),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(
                title: 'Médias semanais',
                subtitle: 'Últimas 8 semanas do indicador selecionado',
              ),
              AppCard(
                child: _WeeklyBars(series: focus, color: color),
              ),
              SectionHeader(
                title: 'Alertas deste dashboard',
                subtitle: '${domainAlerts.length} ativos',
              ),
              if (domainAlerts.isEmpty)
                const AppCard(
                  child: Text('Nenhum alerta ativo para este domínio.'),
                )
              else
                for (final a in domainAlerts)
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
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(SemanticStyle.domainIcon(domain), color: color),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text('Dashboard · ${domain.label}')),
          ],
        ),
      ),
      body: body,
    );
  }
}

/// Gráfico de barras com a média de cada uma das últimas 8 semanas.
class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.series, required this.color});
  final IndicatorSeries series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = series.definition;
    final weeks = <({DateTime start, double mean})>[];
    final pts = series.points;
    for (var end = pts.length; end - 7 >= 0 && weeks.length < 8; end -= 7) {
      final chunk = pts.sublist(end - 7, end);
      final values = chunk
          .where((p) => p.value != null)
          .map((p) => p.value!)
          .toList();
      if (values.isEmpty) continue;
      weeks.insert(0, (start: chunk.first.date, mean: Stats.mean(values)));
    }
    if (weeks.isEmpty) return const Text('Dados insuficientes.');
    final maxY = weeks.map((w) => w.mean).reduce(max) * 1.15;
    final weekText = weeks
        .map(
          (w) =>
              'semana de ${Fmt.day(w.start)}, '
              '${Fmt.number(w.mean, decimals: def.decimals)}',
        )
        .join('; ');
    final description = 'Médias semanais de ${def.name}: $weekText';

    return Semantics(
      label: description,
      excludeSemantics: true,
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= weeks.length) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        Fmt.day(weeks[i].start),
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${Fmt.number(rod.toY, decimals: def.decimals)} ${def.unit}',
                  theme.textTheme.labelMedium!.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < weeks.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: weeks[i].mean,
                      width: 18,
                      color: i == weeks.length - 1
                          ? color
                          : color.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
