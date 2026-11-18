import 'dart:math';

import '../../core/constants/territory.dart';
import '../../data/models/alert.dart';
import '../../data/models/analysis.dart';
import '../../data/models/occurrence.dart';
import 'statistics.dart';

/// Indicadores que conectam o desempenho analítico ao benefício social.
class SocialImpactReport {
  const SocialImpactReport({
    required this.peopleCovered,
    required this.alertsActioned,
    required this.alertsDecided,
    required this.alertsTotal,
    required this.dismissedRate,
    required this.avgResponseTime,
    required this.waterSavedM3,
    required this.citizenReports,
    required this.citizenReportsSynced,
    required this.meanModelAccuracy,
    required this.highConfidenceShare,
  });

  /// Pessoas que vivem em áreas cobertas por alertas tratados por gestores.
  final int peopleCovered;
  final int alertsActioned;
  final int alertsDecided;
  final int alertsTotal;

  /// Fração de alertas descartados como falso positivo pelos gestores —
  /// medida prática da precisão percebida do sistema.
  final double dismissedRate;
  final Duration? avgResponseTime;

  /// Estimativa conservadora de água potencialmente economizada (m³).
  final double waterSavedM3;
  final int citizenReports;
  final int citizenReportsSynced;

  /// Média de (1 − WAPE) dos modelos no backtest.
  final double meanModelAccuracy;

  /// Fração de alertas ativos com confiança alta.
  final double highConfidenceShare;

  double get coverageRatio => peopleCovered / Territory.population;
}

class SocialImpactCalculator {
  const SocialImpactCalculator();

  /// Fração do excedente de consumo considerada evitável por ação rápida
  /// (premissa explícita e exibida na interface).
  static const avoidableShare = 0.25;

  SocialImpactReport compute({
    required List<TerritoryAlert> alerts,
    required Map<String, AlertDecision> decisions,
    required Map<String, IndicatorAnalysis> analyses,
    required List<Occurrence> occurrences,
  }) {
    final alertsById = {for (final a in alerts) a.id: a};
    final relevant = decisions.values
        .where((d) => d.status != DecisionStatus.pending)
        .toList();
    final actioned = relevant.where((d) => d.status.isActioned).toList();
    final dismissed = relevant
        .where((d) => d.status == DecisionStatus.dismissed)
        .length;

    // Pessoas cobertas: maior população por indicador (evita contar duas
    // vezes a mesma população em alertas distintos do mesmo indicador).
    final popByIndicator = <String, int>{};
    for (final d in actioned) {
      final alert = alertsById[d.alertId];
      if (alert == null) continue;
      popByIndicator[alert.indicatorId] = max(
        popByIndicator[alert.indicatorId] ?? 0,
        alert.affectedPopulation,
      );
    }
    final people = min(
      popByIndicator.values.fold<int>(0, (s, p) => s + p),
      Territory.population,
    );

    // Água: excedente diário acima da média × 7 dias × parcela evitável.
    var water = 0.0;
    for (final d in actioned) {
      final alert = alertsById[d.alertId];
      if (alert?.indicatorId != 'water_consumption') continue;
      final a = analyses['water_consumption'];
      if (a?.current == null) continue;
      final excessThousandM3 = max(0.0, a!.current! - a.mean);
      water += excessThousandM3 * 1000 * 7 * avoidableShare;
    }

    final responseTimes = relevant.map((d) => d.responseTime).toList();
    final avgResponse = responseTimes.isEmpty
        ? null
        : Duration(
            seconds:
                (responseTimes.fold<int>(0, (s, d) => s + d.inSeconds) /
                        responseTimes.length)
                    .round(),
          );

    final accuracies = analyses.values
        .where((a) => a.forecast.isNotEmpty)
        .map((a) => a.metrics.accuracy)
        .toList();

    return SocialImpactReport(
      peopleCovered: people,
      alertsActioned: actioned.length,
      alertsDecided: relevant.length,
      alertsTotal: alerts.length,
      dismissedRate: relevant.isEmpty ? 0 : dismissed / relevant.length,
      avgResponseTime: avgResponse,
      waterSavedM3: water,
      citizenReports: occurrences.length,
      citizenReportsSynced: occurrences
          .where((o) => o.syncStatus == SyncStatus.synced)
          .length,
      meanModelAccuracy: Stats.mean(accuracies),
      highConfidenceShare: alerts.isEmpty
          ? 0
          : alerts.where((a) => a.confidence == ConfidenceLevel.high).length /
                alerts.length,
    );
  }
}
