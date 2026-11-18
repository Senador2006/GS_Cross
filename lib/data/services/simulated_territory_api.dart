import 'dart:math';

import '../../core/constants/territory.dart';
import '../models/data_point.dart';
import '../models/indicator.dart';
import '../models/occurrence.dart';
import 'api_exception.dart';

/// Perfil estatístico usado para gerar uma série sintética realista.
class _Profile {
  const _Profile({
    required this.base,
    this.weekly = const [1, 1, 1, 1, 1, 1, 1],
    this.noise = 0.03,
    this.trendPerDay = 0,
    this.missingRate = 0.02,
    this.eventDays = 0,
    this.eventLift = 0,
    this.skewed = false,
  });

  final double base;

  /// Fator multiplicativo por dia da semana (segunda = índice 0).
  final List<double> weekly;

  /// Desvio-padrão relativo do ruído.
  final double noise;

  /// Tendência relativa por dia (0.002 = +0,2% ao dia).
  final double trendPerDay;

  /// Probabilidade de um dia vir sem dado.
  final double missingRate;

  /// Cenário: nos últimos [eventDays] dias o indicador sobe gradualmente
  /// até [eventLift] (ex.: onda de calor, surto de demanda).
  final int eventDays;
  final double eventLift;

  /// Distribuição assimétrica (ex.: chuva — muitos dias secos, poucos fortes).
  final bool skewed;
}

/// API **simulada** de indicadores territoriais.
///
/// Representa o backend da prefeitura/concessionárias que, em produção,
/// agregaria dados de saneamento, energia, zeladoria e saúde. Gera séries
/// determinísticas (mesma data → mesmo valor) com sazonalidade semanal,
/// tendência, ruído, dados faltantes e eventos — o suficiente para exercitar
/// o motor de previsão e os estados de carregamento/erro do app.
class SimulatedTerritoryApi {
  SimulatedTerritoryApi({
    this.latency = const Duration(milliseconds: 700),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static const _profiles = <String, _Profile>{
    'water_consumption': _Profile(
      base: 39,
      weekly: [1.02, 1.0, 0.99, 1.0, 1.01, 1.04, 1.06],
      noise: 0.025,
      trendPerDay: 0.0012,
      eventDays: 10,
      eventLift: 0.10,
    ),
    'water_loss': _Profile(
      base: 31,
      noise: 0.03,
      trendPerDay: 0.0009,
      missingRate: 0.05,
    ),
    'energy_consumption': _Profile(
      base: 545,
      weekly: [1.03, 1.03, 1.03, 1.03, 1.02, 0.95, 0.91],
      noise: 0.025,
      eventDays: 10,
      eventLift: 0.07,
    ),
    'energy_outages': _Profile(
      base: 3.5,
      noise: 0.3,
      eventDays: 3,
      eventLift: 0.9,
    ),
    'waste_collected': _Profile(
      base: 182,
      weekly: [1.15, 1.0, 0.98, 1.0, 1.02, 0.95, 0.9],
      noise: 0.04,
    ),
    'irregular_dumping': _Profile(
      base: 11,
      noise: 0.22,
      trendPerDay: 0.004,
      eventDays: 7,
      eventLift: 0.35,
    ),
    'recycling_rate': _Profile(
      base: 7.4,
      noise: 0.05,
      trendPerDay: -0.003,
      missingRate: 0.04,
    ),
    'health_visits': _Profile(
      base: 1480,
      weekly: [1.12, 1.06, 1.02, 1.0, 0.98, 0.55, 0.3],
      noise: 0.04,
      eventDays: 14,
      eventLift: 0.10,
    ),
    'wait_time': _Profile(
      base: 46,
      weekly: [1.15, 1.06, 1.0, 1.0, 0.98, 0.85, 0.8],
      noise: 0.06,
      trendPerDay: 0.006,
    ),
    'service_requests': _Profile(
      base: 96,
      weekly: [1.15, 1.05, 1.0, 1.0, 1.0, 0.8, 0.7],
      noise: 0.09,
      missingRate: 0.05,
    ),
    // Usados apenas como fallback quando a página do INMET está indisponível.
    'temp_max': _Profile(
      base: 28.5,
      noise: 0.06,
      eventDays: 8,
      eventLift: 0.14,
    ),
    'precipitation': _Profile(base: 6, noise: 1.2, skewed: true),
    'humidity_min': _Profile(
      base: 46,
      noise: 0.15,
      eventDays: 8,
      eventLift: -0.2,
    ),
  };

  DateTime get _today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Retorna as séries sintéticas de recursos, resíduos e serviços.
  Future<List<IndicatorSeries>> fetchIndicators({bool offline = false}) async {
    await Future<void>.delayed(latency);
    if (offline) {
      throw const ApiException(
        'Sem conexão com o servidor de indicadores.',
        isConnectivity: true,
      );
    }
    return [
      for (final def in IndicatorCatalog.all)
        if (def.domain != TerritoryDomain.climate) generate(def),
    ];
  }

  /// Séries de clima sintéticas (fallback quando a fonte pública falha).
  List<IndicatorSeries> syntheticClimate() => [
    for (final def in IndicatorCatalog.byDomain(TerritoryDomain.climate))
      generate(def),
  ];

  /// Simula o envio de uma ocorrência ao backend.
  Future<void> submitOccurrence(
    Occurrence occurrence, {
    bool offline = false,
  }) async {
    await Future<void>.delayed(latency);
    if (offline) {
      throw const ApiException(
        'Sem conexão: a ocorrência ficará na fila.',
        isConnectivity: true,
      );
    }
  }

  IndicatorSeries generate(IndicatorDefinition def) {
    final profile = _profiles[def.id]!;
    final today = _today;
    final days = Territory.historyDays;
    final points = <DataPoint>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      points.add(
        DataPoint(
          date: date,
          value: _valueFor(def, profile, date, daysAgo: i, total: days),
        ),
      );
    }
    return IndicatorSeries(
      definition: def,
      points: points,
      origin: DataOrigin.synthetic,
    );
  }

  double? _valueFor(
    IndicatorDefinition def,
    _Profile p,
    DateTime date, {
    required int daysAgo,
    required int total,
  }) {
    final dayKey = date.difference(DateTime(2026)).inDays;
    final rng = Random(_stableHash(def.id) ^ (dayKey * 7919));
    // Último dia sempre presente para que o "valor atual" exista.
    if (daysAgo > 0 && rng.nextDouble() < p.missingRate) return null;

    final t = total - 1 - daysAgo; // 0 .. total-1
    final weekly = p.weekly[date.weekday - 1];
    final trend = 1 + p.trendPerDay * (t - total);
    var event = 1.0;
    if (p.eventDays > 0 && daysAgo < p.eventDays) {
      final progress = (p.eventDays - daysAgo) / p.eventDays;
      event = 1 + p.eventLift * progress;
    }
    double value;
    if (p.skewed) {
      // Chuva: ~60% dos dias secos, demais seguem distribuição exponencial.
      value = rng.nextDouble() < 0.6
          ? 0
          : -log(1 - rng.nextDouble()) * p.base * 1.8;
    } else {
      value = p.base * weekly * trend * event * (1 + _gaussian(rng) * p.noise);
    }
    value = max(0, value);
    return def.decimals == 0
        ? value.roundToDouble()
        : double.parse(value.toStringAsFixed(def.decimals));
  }

  /// Hash estável entre plataformas (String.hashCode não é garantido).
  static int _stableHash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  static double _gaussian(Random rng) {
    // Box-Muller.
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
