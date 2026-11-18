import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/alert.dart';
import '../../data/models/analysis.dart';
import '../../data/models/indicator.dart';
import '../../data/models/threshold.dart';
import 'common.dart';
import 'semantic_style.dart';
import 'sparkline.dart';

/// Barra de confiança (0–100%) com rótulo textual Alta/Média/Baixa.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({super.key, required this.score, this.compact = false});
  final double score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final level = ConfidenceLevel.fromScore(score);
    final color = SemanticStyle.confidence(context, level);
    final theme = Theme.of(context);
    final label =
        'Confiança ${level.label.toLowerCase()} '
        '(${Fmt.percent(score)})';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Seta + variação percentual, colorida conforme o indicador piora ou melhora.
class TrendBadge extends StatelessWidget {
  const TrendBadge({super.key, required this.analysis, required this.worse});

  final IndicatorAnalysis analysis;
  final WorseDirection worse;

  @override
  Widget build(BuildContext context) {
    final color = SemanticStyle.trend(context, analysis.trend, worse);
    return Semantics(
      label:
          '${analysis.trend.label}, '
          '${Fmt.signedPercent(analysis.changePercent)} na semana',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SemanticStyle.trendIcon(analysis.trend), size: 18, color: color),
          const SizedBox(width: 2),
          Text(
            Fmt.signedPercent(analysis.changePercent),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Aviso fixo de que a decisão final é humana.
class HumanDecisionNotice extends StatelessWidget {
  const HumanDecisionNotice({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_pin_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              compact
                  ? 'Apoio à decisão: a decisão final é sempre humana.'
                  : 'Este sistema apenas APOIA a decisão. Nenhuma ação é '
                        'executada automaticamente: um(a) gestor(a) avalia a '
                        'evidência, as limitações e decide o que fazer.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de KPI de um indicador: valor atual, tendência, nível e sparkline.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.series,
    required this.analysis,
    required this.threshold,
    this.onTap,
  });

  final IndicatorSeries series;
  final IndicatorAnalysis analysis;
  final AlertThreshold threshold;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final def = series.definition;
    final theme = Theme.of(context);
    final current = analysis.current;
    final level = current == null
        ? ThresholdLevel.normal
        : threshold.levelOf(current, def.worseDirection);
    final levelColor = SemanticStyle.level(context, level);
    final valueText = current == null
        ? '—'
        : Fmt.number(current, decimals: def.decimals);
    final semantic =
        '${def.name}: ${Fmt.value(current, def.decimals, def.unit)}. '
        'Situação ${SemanticStyle.levelLabel(level)}. ${analysis.trend.label}, '
        '${Fmt.signedPercent(analysis.changePercent)} na semana. '
        'Toque para ver detalhes e previsão.';

    return AppCard(
      onTap: onTap,
      semanticLabel: semantic,
      borderColor: level == ThresholdLevel.normal ? null : levelColor,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  def.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              StatusPill(
                label: SemanticStyle.levelLabel(level),
                color: levelColor,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.xs,
            children: [
              Text(
                valueText,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  def.unit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TrendBadge(analysis: analysis, worse: def.worseDirection),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 36,
            child: Sparkline(
              values: series.points
                  .skip(max(0, series.points.length - 21))
                  .map((p) => p.value)
                  .toList(),
              color: SemanticStyle.domain(context, def.domain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item de lista de alerta (usado em Visão geral, Alertas e Detalhe).
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.alert,
    required this.status,
    this.onTap,
  });

  final TerritoryAlert alert;
  final DecisionStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SemanticStyle.severity(context, alert.severity);
    final semantic =
        'Alerta ${alert.severity.label}: ${alert.title}. '
        '${alert.kind.label}. Confiança ${alert.confidence.label}. '
        'Status: ${status.label}.';
    return AppCard(
      onTap: onTap,
      semanticLabel: semantic,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        StatusPill(
                          label: alert.severity.label,
                          color: color,
                          icon: SemanticStyle.severityIcon(alert.severity),
                          dense: true,
                        ),
                        StatusPill(
                          label: status.label,
                          color: SemanticStyle.decision(context, status),
                          icon: SemanticStyle.decisionIcon(status),
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(alert.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      alert.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ConfidenceMeter(
                            score: alert.confidenceScore,
                            compact: true,
                          ),
                        ),
                        Text(
                          alert.kind.label,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
