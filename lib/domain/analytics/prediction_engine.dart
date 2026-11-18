import 'dart:math';

import '../../data/models/analysis.dart';
import '../../data/models/data_point.dart';
import '../../data/models/indicator.dart';
import 'statistics.dart';

/// Modelo ajustado: tendência linear + sazonalidade semanal aditiva.
class _FittedModel {
  _FittedModel({
    required this.intercept,
    required this.slope,
    required this.seasonal,
    required this.residualStd,
    required this.r2,
    required this.n,
    required this.origin,
  });

  final double intercept;
  final double slope;

  /// Efeito médio por dia da semana (índice 0 = segunda).
  final List<double> seasonal;
  final double residualStd;
  final double r2;
  final int n;

  /// Data correspondente a x = 0.
  final DateTime origin;

  double predict(DateTime date) {
    final x = date.difference(origin).inDays.toDouble();
    return intercept + slope * x + seasonal[date.weekday - 1];
  }
}

/// Motor de previsão interpretável.
///
/// Por que um modelo simples? Gestores precisam entender *por que* um alerta
/// existe. Tendência linear + padrão semanal é explicável em uma frase,
/// roda no próprio dispositivo (funciona offline) e o erro é medido por
/// backtest — o app mostra esse erro em vez de esconder a incerteza.
class PredictionEngine {
  const PredictionEngine({
    this.trainWindow = 28,
    this.horizon = 7,
    this.backtestDays = 7,
  });

  final int trainWindow;
  final int horizon;
  final int backtestDays;

  static const minSamples = 14;
  static const maxMissingRatio = 0.15;
  static const maxReliableWape = 0.25;
  static const regimeChangeZ = 3.0;

  IndicatorAnalysis analyze(IndicatorSeries series) {
    final def = series.definition;
    final window = series.points.length > trainWindow
        ? series.points.sublist(series.points.length - trainWindow)
        : series.points;
    final valid = window.where((p) => !p.isMissing).toList();
    final missingRatio = window.isEmpty
        ? 1.0
        : 1 - valid.length / window.length;

    final current = series.lastValid?.value;
    final allValid = series.points
        .where((p) => !p.isMissing)
        .map((p) => p.value!)
        .toList();

    // Estatísticas descritivas recentes (14 dias anteriores ao atual).
    final recent = allValid.length > 1
        ? allValid.sublist(max(0, allValid.length - 15), allValid.length - 1)
        : allValid;
    final mean = Stats.mean(recent);
    final std = Stats.stdDev(recent);
    final z = (current == null || std == 0) ? 0.0 : (current - mean) / std;

    final last7 = allValid.length >= 7
        ? allValid.sublist(allValid.length - 7)
        : allValid;
    final prev7 = allValid.length >= 14
        ? allValid.sublist(allValid.length - 14, allValid.length - 7)
        : <double>[];
    final prevMean = Stats.mean(prev7);
    final change = prevMean == 0
        ? 0.0
        : (Stats.mean(last7) - prevMean) / prevMean;

    if (valid.length < 3) {
      return IndicatorAnalysis(
        indicatorId: def.id,
        current: current,
        mean: mean,
        stdDev: std,
        changePercent: change,
        trend: TrendDirection.stable,
        slopePerDay: 0,
        forecast: const [],
        metrics: ModelMetrics(
          mape: 1,
          mae: 0,
          r2: 0,
          sampleSize: valid.length,
          missingRatio: missingRatio,
        ),
        confidenceScore: 0,
        zScore: z,
        reliabilityIssues: const ['Dados insuficientes para gerar previsão.'],
      );
    }

    final model = _fit(valid);

    // Backtest: treina sem os últimos N dias e mede o erro nesses dias.
    var wape = 1.0;
    var mae = 0.0;
    final cutoff = window.last.date.subtract(Duration(days: backtestDays));
    final train = valid.where((p) => !p.date.isAfter(cutoff)).toList();
    final test = valid.where((p) => p.date.isAfter(cutoff)).toList();
    if (train.length >= 7 && test.isNotEmpty) {
      final btModel = _fit(train);
      final actual = test.map((p) => p.value!).toList();
      final predicted = test.map((p) => btModel.predict(p.date)).toList();
      wape = Stats.wape(actual, predicted);
      mae = Stats.mae(actual, predicted);
    }

    // Previsão com intervalo de ~95% que se alarga com o horizonte.
    final lastDate = window.last.date;
    final forecast = <ForecastPoint>[];
    for (var h = 1; h <= horizon; h++) {
      final date = lastDate.add(Duration(days: h));
      final value = max(def.minPlausible, model.predict(date));
      final margin = 1.96 * model.residualStd * sqrt(1 + h / model.n);
      forecast.add(
        ForecastPoint(
          date: date,
          value: value,
          lower: max(def.minPlausible, value - margin),
          upper: min(def.maxPlausible, value + margin),
        ),
      );
    }

    final avg = Stats.mean(valid.map((p) => p.value!).toList());
    final weeklyRel = avg == 0 ? 0.0 : model.slope * 7 / avg;
    final trend = weeklyRel > 0.03
        ? TrendDirection.up
        : weeklyRel < -0.03
        ? TrendDirection.down
        : TrendDirection.stable;

    final errorScore = 1 - min(wape / 0.30, 1.0);
    final completeness = 1 - missingRatio;
    final sizeScore = min(valid.length / trainWindow, 1.0);
    final confidence =
        (0.55 * errorScore + 0.25 * completeness + 0.20 * sizeScore).clamp(
          0.0,
          1.0,
        );

    final issues = <String>[
      if (valid.length < minSamples)
        'Apenas ${valid.length} dias com dado válido (mínimo recomendado: '
            '$minSamples).',
      if (missingRatio > maxMissingRatio)
        '${(missingRatio * 100).round()}% dos dias sem dado na janela de '
            'treino (limite: ${(maxMissingRatio * 100).round()}%).',
      if (wape > maxReliableWape)
        'Erro de backtest de ${(wape * 100).round()}% (acima de '
            '${(maxReliableWape * 100).round()}%): o padrão é irregular '
            'demais para este modelo.',
      if (z.abs() >= regimeChangeZ)
        'Valor atual muito fora do padrão recente (${z.toStringAsFixed(1)} '
            'desvios-padrão): possível mudança de regime não capturada.',
    ];

    return IndicatorAnalysis(
      indicatorId: def.id,
      current: current,
      mean: mean,
      stdDev: std,
      changePercent: change,
      trend: trend,
      slopePerDay: model.slope,
      forecast: forecast,
      metrics: ModelMetrics(
        mape: wape,
        mae: mae,
        r2: model.r2,
        sampleSize: valid.length,
        missingRatio: missingRatio,
      ),
      confidenceScore: confidence,
      zScore: z,
      reliabilityIssues: issues,
    );
  }

  _FittedModel _fit(List<DataPoint> valid) {
    final origin = valid.first.date;
    final x = valid
        .map((p) => p.date.difference(origin).inDays.toDouble())
        .toList();
    final y = valid.map((p) => p.value!).toList();
    final reg = Stats.linearRegression(x, y);

    // Sazonalidade semanal: média dos resíduos por dia da semana.
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (var i = 0; i < valid.length; i++) {
      final r = y[i] - (reg.intercept + reg.slope * x[i]);
      final d = valid[i].date.weekday - 1;
      sums[d] += r;
      counts[d]++;
    }
    final seasonal = [
      for (var d = 0; d < 7; d++) counts[d] >= 2 ? sums[d] / counts[d] : 0.0,
    ];

    var ssRes = 0.0;
    var ssTot = 0.0;
    final my = Stats.mean(y);
    for (var i = 0; i < valid.length; i++) {
      final fitted =
          reg.intercept +
          reg.slope * x[i] +
          seasonal[valid[i].date.weekday - 1];
      ssRes += pow(y[i] - fitted, 2);
      ssTot += pow(y[i] - my, 2);
    }
    final dof = max(1, valid.length - 2);
    return _FittedModel(
      intercept: reg.intercept,
      slope: reg.slope,
      seasonal: seasonal,
      residualStd: sqrt(ssRes / dof),
      r2: ssTot == 0 ? 0 : (1 - ssRes / ssTot).clamp(0.0, 1.0),
      n: valid.length,
      origin: origin,
    );
  }
}
