import 'dart:math';

/// Funções estatísticas puras (sem dependência de Flutter) — testáveis.
class Stats {
  Stats._();

  static double mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  /// Desvio-padrão amostral (n - 1).
  static double stdDev(List<double> v) {
    if (v.length < 2) return 0;
    final m = mean(v);
    final ss = v.fold<double>(0, (acc, x) => acc + (x - m) * (x - m));
    return sqrt(ss / (v.length - 1));
  }

  /// Regressão linear simples por mínimos quadrados.
  static ({double intercept, double slope}) linearRegression(
    List<double> x,
    List<double> y,
  ) {
    assert(x.length == y.length);
    final n = x.length;
    if (n == 0) return (intercept: 0, slope: 0);
    if (n == 1) return (intercept: y.first, slope: 0);
    final mx = mean(x);
    final my = mean(y);
    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (x[i] - mx) * (y[i] - my);
      den += (x[i] - mx) * (x[i] - mx);
    }
    final slope = den == 0 ? 0.0 : num / den;
    return (intercept: my - slope * mx, slope: slope);
  }

  /// Weighted Absolute Percentage Error: soma dos erros absolutos dividida
  /// pela soma dos valores reais. Ao contrário do MAPE, é estável quando há
  /// valores zero (ex.: dias sem chuva).
  static double wape(List<double> actual, List<double> predicted) {
    var errSum = 0.0;
    var actSum = 0.0;
    for (var i = 0; i < actual.length; i++) {
      errSum += (actual[i] - predicted[i]).abs();
      actSum += actual[i].abs();
    }
    if (actSum == 0) return errSum == 0 ? 0 : 1;
    return errSum / actSum;
  }

  static double mae(List<double> actual, List<double> predicted) {
    if (actual.isEmpty) return 0;
    var s = 0.0;
    for (var i = 0; i < actual.length; i++) {
      s += (actual[i] - predicted[i]).abs();
    }
    return s / actual.length;
  }

  /// Função de distribuição acumulada da normal padrão (aprox. de
  /// Abramowitz & Stegun 7.1.26, erro < 1.5e-7).
  static double normalCdf(double z) {
    final t = 1 / (1 + 0.3275911 * z.abs() / sqrt2);
    final y =
        1 -
        (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                        0.284496736) *
                    t +
                0.254829592) *
            t *
            exp(-(z * z) / 2);
    return z >= 0 ? (1 + y) / 2 : (1 - y) / 2;
  }
}
