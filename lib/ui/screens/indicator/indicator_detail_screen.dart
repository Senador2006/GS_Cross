import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/occurrence.dart';
import '../../../data/models/threshold.dart';
import '../../../state/alerts_provider.dart';
import '../../../state/settings_provider.dart';
import '../../../state/territory_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/forecast_chart.dart';
import '../../widgets/insight_widgets.dart';
import '../../widgets/semantic_style.dart';
import '../../widgets/state_views.dart';

/// Detalhe de um indicador: série, previsão, métricas do modelo,
/// limitações e alertas relacionados.
class IndicatorDetailScreen extends StatelessWidget {
  const IndicatorDetailScreen({super.key, required this.indicatorId});
  final String indicatorId;

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final alerts = context.watch<AlertsProvider>();
    final series = territory.seriesById(indicatorId);
    final analysis = territory.analysisById(indicatorId);

    if (series == null || analysis == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Indicador')),
        body: const EmptyView(
          icon: Icons.search_off_rounded,
          title: 'Indicador indisponível',
          message: 'Os dados deste indicador não foram carregados.',
        ),
      );
    }

    final def = series.definition;
    final theme = Theme.of(context);
    final threshold = settings.thresholdFor(indicatorId);
    final related = alerts.forIndicator(indicatorId);
    final level = analysis.current == null
        ? ThresholdLevel.normal
        : threshold.levelOf(analysis.current!, def.worseDirection);
    final m = analysis.metrics;
    final dec = def.decimals;
    final category = OccurrenceCategory.values
        .where((c) => c.relatedIndicatorId == indicatorId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(def.name)),
      body: ResponsiveBody(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        SemanticStyle.domainIcon(def.domain),
                        color: SemanticStyle.domain(context, def.domain),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          def.domain.subtitle,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      StatusPill(
                        label: SemanticStyle.levelLabel(level),
                        color: SemanticStyle.level(context, level),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label:
                        'Valor atual ${Fmt.value(analysis.current, dec, def.unit)}',
                    excludeSemantics: true,
                    child: Text(
                      Fmt.value(analysis.current, dec, def.unit),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (series.lastValid != null)
                    Text(
                      'Última medição em ${Fmt.date(series.lastValid!.date)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  TrendBadge(analysis: analysis, worse: def.worseDirection),
                  const SizedBox(height: AppSpacing.md),
                  Text(def.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Fonte: ${series.origin.label}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SectionHeader(
              title: 'Histórico de 60 dias e previsão de 7 dias',
            ),
            AppCard(
              child: ForecastChart(
                series: series,
                analysis: analysis,
                threshold: threshold,
                historyDays: 60,
              ),
            ),
            const SectionHeader(title: 'Previsão dia a dia'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: analysis.forecast.isEmpty
                  ? const Text('Sem previsão: dados insuficientes.')
                  : Column(
                      children: [
                        for (final f in analysis.forecast)
                          InfoRow(
                            label: Fmt.weekday(f.date),
                            value:
                                '${Fmt.number(f.value, decimals: dec)} '
                                '(${Fmt.number(f.lower, decimals: dec)}–'
                                '${Fmt.number(f.upper, decimals: dec)})',
                          ),
                      ],
                    ),
            ),
            const SectionHeader(
              title: 'Qualidade do modelo',
              subtitle: 'Backtest: treina sem os últimos 7 dias e compara',
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConfidenceMeter(score: analysis.confidenceScore),
                  const SizedBox(height: AppSpacing.md),
                  InfoRow(
                    label: 'Erro percentual (WAPE)',
                    value: Fmt.percent(m.mape, decimals: 1),
                  ),
                  InfoRow(
                    label: 'Erro absoluto médio',
                    value: '${Fmt.number(m.mae, decimals: dec)} ${def.unit}',
                  ),
                  InfoRow(
                    label: 'Ajuste aos dados (R²)',
                    value: Fmt.number(m.r2, decimals: 2),
                  ),
                  InfoRow(
                    label: 'Dias válidos na janela',
                    value: '${m.sampleSize} de 28',
                  ),
                  InfoRow(
                    label: 'Dados faltantes',
                    value: Fmt.percent(m.missingRatio),
                  ),
                  InfoRow(
                    label: 'Média 14 dias',
                    value: Fmt.value(analysis.mean, dec, def.unit),
                  ),
                  InfoRow(
                    label: 'Desvio-padrão',
                    value: Fmt.number(analysis.stdDev, decimals: dec),
                  ),
                  InfoRow(
                    label: 'Escore z do valor atual',
                    value: Fmt.number(analysis.zScore, decimals: 2),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (analysis.isReliable)
                    const BulletList(
                      icon: Icons.check_circle_outline_rounded,
                      iconSize: 18,
                      items: [
                        'Nenhuma condição de baixa confiabilidade detectada.',
                      ],
                    )
                  else ...[
                    Text(
                      'Quando NÃO confiar nesta previsão:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    BulletList(
                      icon: Icons.warning_amber_rounded,
                      iconSize: 18,
                      iconColor: theme.colorScheme.error,
                      items: analysis.reliabilityIssues,
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.transparency),
                      child: const Text('Como o modelo funciona'),
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(
              title: 'Limiares de alerta',
              actionLabel: settings.isManager ? 'Configurar' : null,
              onAction: () => Navigator.pushNamed(
                context,
                AppRoutes.thresholds,
                arguments: ThresholdsArgs(focusIndicatorId: indicatorId),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  InfoRow(
                    label: 'Atenção',
                    value: Fmt.value(threshold.warning, dec, def.unit),
                  ),
                  InfoRow(
                    label: 'Crítico',
                    value: Fmt.value(threshold.critical, dec, def.unit),
                  ),
                  InfoRow(
                    label: 'Alertas para este indicador',
                    value: threshold.enabled ? 'Ativos' : 'Desativados',
                  ),
                ],
              ),
            ),
            SectionHeader(
              title: 'Alertas relacionados',
              subtitle: '${related.length} ativos',
            ),
            if (related.isEmpty)
              const AppCard(child: Text('Nenhum alerta para este indicador.'))
            else
              for (final a in related)
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
            if (category != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.occurrenceNew,
                  arguments: OccurrenceFormArgs(category: category),
                ),
                icon: const Icon(Icons.campaign_rounded),
                label: Text('Relatar "${category.label}"'),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
