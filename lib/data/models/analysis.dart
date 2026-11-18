/// Nível de confiança apresentado ao usuário.
enum ConfidenceLevel {
  high('Alta'),
  medium('Média'),
  low('Baixa');

  const ConfidenceLevel(this.label);
  final String label;

  static ConfidenceLevel fromScore(double score) {
    if (score >= 0.75) return ConfidenceLevel.high;
    if (score >= 0.5) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

enum TrendDirection {
  up('Em alta'),
  down('Em queda'),
  stable('Estável');

  const TrendDirection(this.label);
  final String label;
}

/// Um ponto previsto, com intervalo de predição de ~95%.
class ForecastPoint {
  const ForecastPoint({
    required this.date,
    required this.value,
    required this.lower,
    required this.upper,
  });

  final DateTime date;
  final double value;
  final double lower;
  final double upper;
}

/// Métricas de qualidade do modelo, calculadas por backtest
/// (treina sem os últimos 7 dias e compara com o observado).
class ModelMetrics {
  const ModelMetrics({
    required this.mape,
    required this.mae,
    required this.r2,
    required this.sampleSize,
    required this.missingRatio,
  });

  /// Erro percentual absoluto médio no backtest (0.08 = 8%).
  final double mape;

  /// Erro absoluto médio no backtest, na unidade do indicador.
  final double mae;

  /// Coeficiente de determinação do ajuste (tendência + sazonalidade).
  final double r2;
  final int sampleSize;

  /// Fração de dias sem dado na janela de treino.
  final double missingRatio;

  double get accuracy => (1 - mape).clamp(0, 1).toDouble();
}

/// Resultado completo da análise de um indicador.
class IndicatorAnalysis {
  const IndicatorAnalysis({
    required this.indicatorId,
    required this.current,
    required this.mean,
    required this.stdDev,
    required this.changePercent,
    required this.trend,
    required this.slopePerDay,
    required this.forecast,
    required this.metrics,
    required this.confidenceScore,
    required this.zScore,
    required this.reliabilityIssues,
  });

  final String indicatorId;
  final double? current;

  /// Média e desvio-padrão da janela recente (14 dias).
  final double mean;
  final double stdDev;

  /// Variação da média dos últimos 7 dias vs. os 7 anteriores.
  final double changePercent;
  final TrendDirection trend;
  final double slopePerDay;
  final List<ForecastPoint> forecast;
  final ModelMetrics metrics;

  /// 0..1 — combina erro de backtest, completude e tamanho da amostra.
  final double confidenceScore;

  /// Desvio do valor atual em relação à média recente, em desvios-padrão.
  final double zScore;

  /// Condições em que a previsão NÃO deve ser considerada confiável.
  final List<String> reliabilityIssues;

  ConfidenceLevel get confidence => ConfidenceLevel.fromScore(confidenceScore);
  bool get isReliable => reliabilityIssues.isEmpty;
}
