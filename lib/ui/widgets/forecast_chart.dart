import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/analysis.dart';
import '../../data/models/indicator.dart';
import '../../data/models/threshold.dart';
import 'semantic_style.dart';

/// Gráfico de histórico + previsão de 7 dias com faixa de incerteza (95%)
/// e linhas de limiar. Inclui descrição textual para leitores de tela.
class ForecastChart extends StatelessWidget {
  const ForecastChart({
    super.key,
    required this.series,
    required this.analysis,
    required this.threshold,
    this.historyDays = 30,
    this.showForecast = true,
    this.height = 240,
  });

  final IndicatorSeries series;
  final IndicatorAnalysis analysis;
  final AlertThreshold threshold;
  final int historyDays;
  final bool showForecast;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final def = series.definition;
    final histColor = dark
        ? AppColors.chartHistoryDark
        : AppColors.chartHistory;
    final fcColor = dark
        ? AppColors.chartForecastDark
        : AppColors.chartForecast;

    final pts = series.points.length > historyDays
        ? series.points.sublist(series.points.length - historyDays)
        : series.points;
    final forecast = showForecast ? analysis.forecast : <ForecastPoint>[];
    final dates = [...pts.map((p) => p.date), ...forecast.map((f) => f.date)];

    final history = <FlSpot>[
      for (var i = 0; i < pts.length; i++)
        pts[i].value == null
            ? FlSpot.nullSpot
            : FlSpot(i.toDouble(), pts[i].value!),
    ];

    // A previsão começa no último ponto observado para a linha ser contínua.
    final lastIdx = pts.lastIndexWhere((p) => p.value != null);
    final anchor = lastIdx >= 0
        ? [FlSpot(lastIdx.toDouble(), pts[lastIdx].value!)]
        : <FlSpot>[];
    final base = pts.length.toDouble();
    final fcMean = [
      ...anchor,
      for (var i = 0; i < forecast.length; i++)
        FlSpot(base + i, forecast[i].value),
    ];
    final fcUpper = [
      ...anchor,
      for (var i = 0; i < forecast.length; i++)
        FlSpot(base + i, forecast[i].upper),
    ];
    final fcLower = [
      ...anchor,
      for (var i = 0; i < forecast.length; i++)
        FlSpot(base + i, forecast[i].lower),
    ];

    final values = [
      ...pts.where((p) => p.value != null).map((p) => p.value!),
      ...forecast.expand((f) => [f.lower, f.upper]),
      if (threshold.enabled) ...[threshold.warning, threshold.critical],
    ];
    var minY = values.isEmpty ? 0.0 : values.reduce(min);
    var maxY = values.isEmpty ? 1.0 : values.reduce(max);
    final pad = max((maxY - minY) * 0.12, 1.0);
    minY = max(def.minPlausible, minY - pad);
    maxY = maxY + pad;

    final labelStep = max(1, (dates.length / 5).ceil());
    final warnColor = SemanticStyle.level(context, ThresholdLevel.warning);
    final critColor = SemanticStyle.level(context, ThresholdLevel.critical);

    final chart = LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: max(1, dates.length - 1).toDouble(),
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  Fmt.compact(value),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= dates.length || i % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    Fmt.day(dates[i]),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: threshold.enabled
              ? [
                  _limitLine(threshold.warning, warnColor, 'Atenção', theme),
                  _limitLine(threshold.critical, critColor, 'Crítico', theme),
                ]
              : [],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => spots.map((s) {
              // Só mostra tooltip para histórico (0) e previsão média (1).
              if (s.barIndex > 1) return null;
              final i = s.x.round().clamp(0, dates.length - 1);
              final prefix = s.barIndex == 0 ? '' : 'Previsto · ';
              return LineTooltipItem(
                '$prefix${Fmt.day(dates[i])}\n'
                '${Fmt.number(s.y, decimals: def.decimals)} ${def.unit}',
                theme.textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: history,
            isCurved: true,
            preventCurveOverShooting: true,
            color: histColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: fcMean,
            isCurved: false,
            color: fcColor,
            barWidth: 2.5,
            dashArray: const [6, 4],
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 2.5,
                color: fcColor,
                strokeWidth: 0,
              ),
            ),
          ),
          LineChartBarData(
            spots: fcUpper,
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: fcLower,
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          ),
        ],
        betweenBarsData: forecast.isEmpty
            ? []
            : [
                BetweenBarsData(
                  fromIndex: 2,
                  toIndex: 3,
                  color: fcColor.withValues(alpha: 0.18),
                ),
              ],
      ),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _describe(def, pts.length, forecast),
          image: true,
          excludeSemantics: true,
          child: SizedBox(height: height, child: chart),
        ),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _Legend(color: histColor, label: 'Histórico'),
              if (forecast.isNotEmpty) ...[
                _Legend(color: fcColor, label: 'Previsão', dashed: true),
                _Legend(
                  color: fcColor.withValues(alpha: 0.35),
                  label: 'Intervalo 95%',
                  box: true,
                ),
              ],
              if (threshold.enabled) ...[
                _Legend(color: warnColor, label: 'Limiar de atenção'),
                _Legend(color: critColor, label: 'Limiar crítico'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  HorizontalLine _limitLine(
    double y,
    Color color,
    String label,
    ThemeData theme,
  ) => HorizontalLine(
    y: y,
    color: color.withValues(alpha: 0.85),
    strokeWidth: 1.5,
    dashArray: const [4, 4],
    label: HorizontalLineLabel(
      show: true,
      alignment: Alignment.topRight,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
      labelResolver: (_) => label,
    ),
  );

  String _describe(
    IndicatorDefinition def,
    int days,
    List<ForecastPoint> forecast,
  ) {
    final b = StringBuffer('Gráfico de ${def.name}, últimos $days dias. ');
    final current = analysis.current;
    b.write('Valor atual ${Fmt.value(current, def.decimals, def.unit)}. ');
    b.write(
      'Média recente ${Fmt.value(analysis.mean, def.decimals, def.unit)}. ',
    );
    b.write('Tendência: ${analysis.trend.label.toLowerCase()}. ');
    if (forecast.isNotEmpty) {
      final last = forecast.last;
      b.write(
        'Previsão para ${Fmt.day(last.date)}: '
        '${Fmt.value(last.value, def.decimals, def.unit)}, entre '
        '${Fmt.number(last.lower, decimals: def.decimals)} e '
        '${Fmt.number(last.upper, decimals: def.decimals)}. ',
      );
    }
    if (threshold.enabled) {
      b.write(
        'Limiar de atenção ${Fmt.number(threshold.warning)}, '
        'crítico ${Fmt.number(threshold.critical)}.',
      );
    }
    return b.toString();
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
    this.box = false,
  });

  final Color color;
  final String label;
  final bool dashed;
  final bool box;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: box ? 10 : 3,
        decoration: BoxDecoration(
          color: dashed ? null : color,
          border: dashed ? Border.all(color: color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
