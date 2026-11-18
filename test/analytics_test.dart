import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:radar_territorial/core/constants/territory.dart';
import 'package:radar_territorial/data/models/alert.dart';
import 'package:radar_territorial/data/models/analysis.dart';
import 'package:radar_territorial/data/models/data_point.dart';
import 'package:radar_territorial/data/models/indicator.dart';
import 'package:radar_territorial/data/models/occurrence.dart';
import 'package:radar_territorial/data/models/threshold.dart';
import 'package:radar_territorial/domain/analytics/alert_engine.dart';
import 'package:radar_territorial/domain/analytics/prediction_engine.dart';
import 'package:radar_territorial/domain/analytics/social_impact.dart';
import 'package:radar_territorial/domain/analytics/statistics.dart';

IndicatorSeries _series(String id, List<double?> values) {
  final start = DateTime(2026, 9, 1);
  return IndicatorSeries(
    definition: IndicatorCatalog.byId(id),
    origin: DataOrigin.synthetic,
    points: [
      for (var i = 0; i < values.length; i++)
        DataPoint(
          date: start.add(Duration(days: i)),
          value: values[i],
        ),
    ],
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Stats', () {
    test('média e desvio-padrão amostral', () {
      expect(Stats.mean([2, 4, 6]), 4);
      expect(Stats.stdDev([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(2.138, 0.001));
    });

    test('regressão linear recupera reta exata', () {
      final r = Stats.linearRegression([0, 1, 2, 3], [1, 3, 5, 7]);
      expect(r.slope, closeTo(2, 1e-9));
      expect(r.intercept, closeTo(1, 1e-9));
    });

    test('WAPE é estável com zeros', () {
      expect(Stats.wape([0, 0], [0, 0]), 0);
      expect(Stats.wape([10, 0], [8, 2]), closeTo(0.4, 1e-9));
    });

    test('CDF normal', () {
      expect(Stats.normalCdf(0), closeTo(0.5, 1e-6));
      expect(Stats.normalCdf(1.96), closeTo(0.975, 1e-3));
      expect(Stats.normalCdf(-1.96), closeTo(0.025, 1e-3));
    });
  });

  group('PredictionEngine', () {
    const engine = PredictionEngine();

    test('série com tendência limpa → previsão precisa e confiança alta', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 40; i++) 30 + 0.2 * i,
      ]);
      final a = engine.analyze(s);
      expect(a.forecast, hasLength(7));
      // Último valor = 30 + 0.2*39 = 37.8; próximo ≈ 38.0
      expect(a.forecast.first.value, closeTo(38.0, 0.05));
      expect(a.trend, TrendDirection.up);
      expect(a.metrics.mape, lessThan(0.01));
      expect(a.confidence, ConfidenceLevel.high);
      expect(a.isReliable, isTrue);
    });

    test('intervalo de previsão contém o valor e se alarga', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 40; i++) 30 + (i.isEven ? 1.5 : -1.5),
      ]);
      final a = engine.analyze(s);
      for (final f in a.forecast) {
        expect(f.lower, lessThanOrEqualTo(f.value));
        expect(f.upper, greaterThanOrEqualTo(f.value));
      }
      final first = a.forecast.first;
      final last = a.forecast.last;
      expect(
        last.upper - last.lower,
        greaterThanOrEqualTo(first.upper - first.lower),
      );
    });

    test('muitos dados faltantes → sinaliza baixa confiabilidade', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 40; i++) i % 3 == 0 ? null : 30.0 + i % 5,
      ]);
      final a = engine.analyze(s);
      expect(a.metrics.missingRatio, greaterThan(0.15));
      expect(a.isReliable, isFalse);
      expect(a.reliabilityIssues.join(), contains('sem dado'));
    });

    test('dados insuficientes → sem previsão', () {
      final s = _series('water_consumption', [10, null]);
      final a = engine.analyze(s);
      expect(a.forecast, isEmpty);
      expect(a.confidenceScore, 0);
    });
  });

  group('AlertEngine', () {
    const prediction = PredictionEngine();
    const engine = AlertEngine();
    final thresholds = {
      for (final d in IndicatorCatalog.all) d.id: AlertThreshold.defaultFor(d),
    };

    List<TerritoryAlert> run(
      IndicatorSeries s, {
      List<Occurrence> occurrences = const [],
    }) {
      return engine.generate(
        series: [s],
        analyses: {s.id: prediction.analyze(s)},
        thresholds: thresholds,
        occurrences: occurrences,
        now: s.points.last.date,
      );
    }

    test('valor acima do crítico → alerta crítico com evidência', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 39; i++) 40.0,
        50.0,
      ]);
      final alerts = run(s);
      expect(alerts, hasLength(1));
      final a = alerts.single;
      expect(a.kind, AlertKind.thresholdBreach);
      expect(a.severity, AlertSeverity.critical);
      expect(a.evidence, isNotEmpty);
      expect(a.limitations, isNotEmpty);
      expect(a.suggestedActions, isNotEmpty);
    });

    test('tendência que cruza o limiar → alerta de previsão', () {
      // Sobe 0.2/dia, hoje 41.8; atenção em 44 → cruza em ~11 dias? Não.
      // Usa inclinação maior para cruzar dentro de 7 dias.
      final s = _series('water_consumption', [
        for (var i = 0; i < 40; i++) 30 + 0.35 * i,
      ]);
      final alerts = run(s);
      expect(alerts.single.kind, AlertKind.predictedBreach);
      expect(alerts.single.expectedDate, isNotNull);
    });

    test('indicador "pior quando menor" respeita a direção', () {
      final s = _series('recycling_rate', [
        for (var i = 0; i < 39; i++) 7.5,
        3.0,
      ]);
      final alerts = run(s);
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('sem anomalias nem limiares → nenhum alerta', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 40; i++) 38 + (i.isEven ? 0.3 : -0.3),
      ]);
      expect(run(s), isEmpty);
    });

    test('3+ relatos da mesma categoria → alerta cidadão', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 40; i++) 38.0,
      ]);
      final now = s.points.last.date;
      final occ = [
        for (var i = 0; i < 3; i++)
          Occurrence(
            id: 'o$i',
            category: OccurrenceCategory.waterLeak,
            title: 'Vazamento',
            description: 'Vazamento na rua principal do bairro.',
            neighborhood: Territory.neighborhoods[i],
            severity: OccurrenceSeverity.high,
            occurredOn: now.subtract(Duration(days: i)),
            createdAt: now,
            reporterHash: 'abc',
            syncStatus: SyncStatus.synced,
          ),
      ];
      final alerts = run(s, occurrences: occ);
      final citizen = alerts
          .where((a) => a.kind == AlertKind.citizenReports)
          .toList();
      expect(citizen, hasLength(1));
      expect(citizen.single.severity, AlertSeverity.warning);
      expect(citizen.single.confidenceScore, lessThanOrEqualTo(0.8));
    });
  });

  group('SocialImpactCalculator', () {
    test('só decisões com ação contam como benefício', () {
      final s = _series('water_consumption', [
        for (var i = 0; i < 39; i++) 40.0,
        50.0,
      ]);
      final analysis = const PredictionEngine().analyze(s);
      final alerts = const AlertEngine().generate(
        series: [s],
        analyses: {s.id: analysis},
        thresholds: {s.id: AlertThreshold.defaultFor(s.definition)},
        occurrences: const [],
        now: DateTime(2026, 10, 10),
      );
      final alert = alerts.single;
      AlertDecision decision(DecisionStatus st) => AlertDecision(
        alertId: alert.id,
        status: st,
        note: 'nota de teste',
        decidedAt: alert.generatedAt.add(const Duration(hours: 2)),
        alertGeneratedAt: alert.generatedAt,
      );

      const calc = SocialImpactCalculator();
      final dismissed = calc.compute(
        alerts: alerts,
        decisions: {alert.id: decision(DecisionStatus.dismissed)},
        analyses: {s.id: analysis},
        occurrences: const [],
      );
      expect(dismissed.peopleCovered, 0);
      expect(dismissed.dismissedRate, 1);

      final acted = calc.compute(
        alerts: alerts,
        decisions: {alert.id: decision(DecisionStatus.forwarded)},
        analyses: {s.id: analysis},
        occurrences: const [],
      );
      expect(acted.peopleCovered, Territory.population);
      expect(acted.waterSavedM3, greaterThan(0));
      expect(acted.avgResponseTime, const Duration(hours: 2));
    });
  });
}
