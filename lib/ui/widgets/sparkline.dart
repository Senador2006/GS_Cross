import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

/// Mini gráfico de linha sem eixos (decorativo — a informação textual
/// equivalente já está no card, por isso é excluído da semântica).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double?> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), values[i]!),
    ];
    if (spots.where((s) => s != FlSpot.nullSpot).length < 2) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
