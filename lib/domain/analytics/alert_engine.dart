import 'dart:math';

import '../../core/utils/formatters.dart';
import '../../data/models/alert.dart';
import '../../data/models/analysis.dart';
import '../../data/models/indicator.dart';
import '../../data/models/occurrence.dart';
import '../../data/models/threshold.dart';
import 'statistics.dart';

/// Gera alertas a partir de regras (limiares) e previsões.
///
/// Princípios:
/// * todo alerta traz a evidência numérica que o originou;
/// * alertas preditivos com confiança baixa são rebaixados a "informativo"
///   para evitar alarmismo;
/// * o motor apenas **sugere** ações — nenhuma ação é executada
///   automaticamente; a decisão é registrada por uma pessoa.
class AlertEngine {
  const AlertEngine();

  static const anomalyZ = 2.5;
  static const trendChange = 0.08;
  static const citizenReportsMin = 3;

  List<TerritoryAlert> generate({
    required List<IndicatorSeries> series,
    required Map<String, IndicatorAnalysis> analyses,
    required Map<String, AlertThreshold> thresholds,
    required List<Occurrence> occurrences,
    required DateTime now,
  }) {
    final alerts = <TerritoryAlert>[];
    for (final s in series) {
      final analysis = analyses[s.id];
      final threshold = thresholds[s.id];
      if (analysis == null || threshold == null || !threshold.enabled) {
        continue;
      }
      final alert = _indicatorAlert(s, analysis, threshold, now);
      if (alert != null) alerts.add(alert);
    }
    alerts.addAll(_citizenAlerts(occurrences, now));
    alerts.sort((a, b) {
      final bySeverity = b.severity.weight.compareTo(a.severity.weight);
      if (bySeverity != 0) return bySeverity;
      return b.confidenceScore.compareTo(a.confidenceScore);
    });
    return alerts;
  }

  /// No máximo um alerta por indicador, na ordem de prioridade:
  /// limiar atual → previsão → anomalia → tendência.
  TerritoryAlert? _indicatorAlert(
    IndicatorSeries s,
    IndicatorAnalysis a,
    AlertThreshold t,
    DateTime now,
  ) {
    final def = s.definition;
    final last = s.lastValid;
    if (last == null || a.current == null) return null;
    final current = a.current!;
    final dir = def.worseDirection;
    final unit = def.unit;
    final dec = def.decimals;
    String v(double x) => Fmt.value(x, dec, unit);
    final refKey = _dateKey(last.date);

    final baseLimitations = _baseLimitations(s, a);
    final daysOver = _daysBeyond(s, t.warning, dir, 7);

    // 1) Limiar já ultrapassado.
    final level = t.levelOf(current, dir);
    if (level != ThresholdLevel.normal) {
      final isCritical = level == ThresholdLevel.critical;
      final limit = isCritical ? t.critical : t.warning;
      // Confiança de uma observação depende da qualidade do dado, não do
      // modelo: completude e consistência dos últimos dias.
      final conf =
          (0.55 +
                  0.30 * (1 - a.metrics.missingRatio) +
                  0.15 * min(daysOver / 3, 1.0))
              .clamp(0.0, 1.0);
      return TerritoryAlert(
        id: '${def.id}_${AlertKind.thresholdBreach.name}_$refKey',
        indicatorId: def.id,
        kind: AlertKind.thresholdBreach,
        severity: isCritical ? AlertSeverity.critical : AlertSeverity.warning,
        title:
            '${def.name} ${_side(dir)} do limiar '
            '${isCritical ? 'crítico' : 'de atenção'}',
        summary:
            'Valor de ${v(current)} em ${Fmt.day(last.date)}, '
            '${_side(dir)} do limiar de ${v(limit)}.',
        evidence: [
          'Valor observado em ${Fmt.day(last.date)}: ${v(current)}.',
          'Limiar ${isCritical ? 'crítico' : 'de atenção'} configurado: '
              '${v(limit)}.',
          'Média dos 14 dias anteriores: ${v(a.mean)} '
              '(desvio-padrão ${Fmt.number(a.stdDev, decimals: dec)}).',
          '$daysOver dos últimos 7 dias além do limiar de atenção.',
          'Variação da média semanal: ${Fmt.signedPercent(a.changePercent)}.',
        ],
        confidenceScore: conf,
        limitations: baseLimitations,
        suggestedActions: _actions(def.id),
        generatedAt: now,
        affectedPopulation: def.affectedPopulation,
      );
    }

    // 2) Previsão de ultrapassagem nos próximos dias.
    for (final f in a.forecast) {
      final fLevel = t.levelOf(f.value, dir);
      if (fLevel == ThresholdLevel.normal) continue;
      final isCritical = fLevel == ThresholdLevel.critical;
      final limit = isCritical ? t.critical : t.warning;
      final sigma = (f.upper - f.lower) / 3.92;
      final zLimit = sigma == 0 ? 0.0 : (f.value - limit) / sigma;
      final prob = dir == WorseDirection.higher
          ? Stats.normalCdf(zLimit)
          : Stats.normalCdf(-zLimit);
      final lowConfidence = a.confidence == ConfidenceLevel.low;
      final days = f.date.difference(last.date).inDays;
      return TerritoryAlert(
        id: '${def.id}_${AlertKind.predictedBreach.name}_$refKey',
        indicatorId: def.id,
        kind: AlertKind.predictedBreach,
        severity: lowConfidence
            ? AlertSeverity.info
            : (isCritical ? AlertSeverity.critical : AlertSeverity.warning),
        title:
            '${def.name}: previsão de ultrapassar o limiar em '
            '$days ${days == 1 ? 'dia' : 'dias'}',
        summary:
            'O modelo projeta ${v(f.value)} para ${Fmt.weekday(f.date)} '
            '(limiar ${isCritical ? 'crítico' : 'de atenção'}: ${v(limit)}).',
        evidence: [
          'Previsão para ${Fmt.day(f.date)}: ${v(f.value)} '
              '(intervalo de 95%: ${Fmt.number(f.lower, decimals: dec)} a '
              '${Fmt.number(f.upper, decimals: dec)} $unit).',
          'Probabilidade estimada de ultrapassar o limiar nesse dia: '
              '${Fmt.percent(prob)}.',
          'Valor atual: ${v(current)}; tendência de '
              '${a.slopePerDay >= 0 ? '+' : '−'}'
              '${Fmt.number(a.slopePerDay.abs(), decimals: max(dec, 1))} '
              '$unit por dia.',
          'Erro do modelo no backtest de 7 dias (WAPE): '
              '${Fmt.percent(a.metrics.mape, decimals: 1)}.',
        ],
        confidenceScore: a.confidenceScore,
        limitations: [
          if (lowConfidence)
            'Confiança baixa: alerta rebaixado para "informativo" para evitar '
                'mobilização desnecessária.',
          ...baseLimitations,
        ],
        suggestedActions: _actions(def.id),
        generatedAt: now,
        affectedPopulation: def.affectedPopulation,
        expectedDate: f.date,
      );
    }

    // 3) Anomalia estatística (fora do padrão, mesmo sem limiar).
    final worseZ = dir == WorseDirection.higher ? a.zScore : -a.zScore;
    if (a.zScore.abs() >= anomalyZ) {
      return TerritoryAlert(
        id: '${def.id}_${AlertKind.anomaly.name}_$refKey',
        indicatorId: def.id,
        kind: AlertKind.anomaly,
        severity: worseZ > 0 ? AlertSeverity.warning : AlertSeverity.info,
        title: '${def.name} fora do padrão recente',
        summary:
            'O valor de ${v(current)} está '
            '${Fmt.number(a.zScore.abs(), decimals: 1)} desvios-padrão '
            '${a.zScore > 0 ? 'acima' : 'abaixo'} da média de 14 dias.',
        evidence: [
          'Valor atual: ${v(current)}.',
          'Média de 14 dias: ${v(a.mean)}; desvio-padrão: '
              '${Fmt.number(a.stdDev, decimals: dec)}.',
          'Escore z = ${Fmt.number(a.zScore, decimals: 2)} '
              '(regra: |z| ≥ ${Fmt.number(anomalyZ)}).',
        ],
        confidenceScore: min(
          0.9,
          0.5 +
              (a.zScore.abs() - anomalyZ) * 0.15 +
              0.2 * (1 - a.metrics.missingRatio),
        ),
        limitations: [
          'Uma anomalia isolada pode ser erro de medição ou evento pontual.',
          ...baseLimitations,
        ],
        suggestedActions: [
          'Verificar a qualidade do dado junto à fonte antes de agir.',
          ..._actions(def.id),
        ],
        generatedAt: now,
        affectedPopulation: def.affectedPopulation,
      );
    }

    // 4) Tendência persistente na direção ruim.
    final worseChange = dir == WorseDirection.higher
        ? a.changePercent
        : -a.changePercent;
    final worseTrend = dir == WorseDirection.higher
        ? a.trend == TrendDirection.up
        : a.trend == TrendDirection.down;
    if (worseTrend && worseChange >= trendChange) {
      return TerritoryAlert(
        id: '${def.id}_${AlertKind.trend.name}_$refKey',
        indicatorId: def.id,
        kind: AlertKind.trend,
        severity: AlertSeverity.info,
        title: '${def.name}: tendência de piora',
        summary:
            'A média da última semana variou '
            '${Fmt.signedPercent(a.changePercent)} em relação à anterior.',
        evidence: [
          'Média dos últimos 7 dias vs. 7 anteriores: '
              '${Fmt.signedPercent(a.changePercent)}.',
          'Inclinação da tendência (28 dias): '
              '${Fmt.number(a.slopePerDay, decimals: max(dec, 1))} $unit/dia.',
          'Ainda abaixo dos limiares configurados.',
        ],
        confidenceScore: a.confidenceScore,
        limitations: baseLimitations,
        suggestedActions: _actions(def.id),
        generatedAt: now,
        affectedPopulation: def.affectedPopulation,
      );
    }
    return null;
  }

  List<TerritoryAlert> _citizenAlerts(List<Occurrence> items, DateTime now) {
    final since = now.subtract(const Duration(days: 7));
    final recent = items.where((o) => o.occurredOn.isAfter(since));
    final byCategory = <OccurrenceCategory, List<Occurrence>>{};
    for (final o in recent) {
      byCategory.putIfAbsent(o.category, () => []).add(o);
    }
    final alerts = <TerritoryAlert>[];
    byCategory.forEach((cat, list) {
      if (list.length < citizenReportsMin) return;
      final high = list
          .where((o) => o.severity == OccurrenceSeverity.high)
          .length;
      final hoods = list.map((o) => o.neighborhood).toSet().toList()..sort();
      final people = list.fold<int>(0, (s, o) => s + (o.affectedPeople ?? 0));
      alerts.add(
        TerritoryAlert(
          id: 'citizen_${cat.name}_${_dateKey(now)}',
          indicatorId: cat.relatedIndicatorId,
          kind: AlertKind.citizenReports,
          severity: high >= 2 ? AlertSeverity.warning : AlertSeverity.info,
          title: '${list.length} relatos de "${cat.label}" em 7 dias',
          summary:
              'Cidadãos registraram ${list.length} ocorrências da '
              'categoria, em ${hoods.length} '
              '${hoods.length == 1 ? 'bairro' : 'bairros'}.',
          evidence: [
            '${list.length} relatos nos últimos 7 dias '
                '(regra: ≥ $citizenReportsMin).',
            '$high marcados como gravidade alta.',
            'Bairros: ${hoods.join(', ')}.',
            if (people > 0) 'Pessoas afetadas declaradas: $people.',
          ],
          confidenceScore: min(0.8, 0.35 + 0.08 * list.length),
          limitations: const [
            'Relatos são voluntários e não verificados individualmente.',
            'Viés de participação: bairros com menos acesso a smartphone '
                'tendem a ser sub-representados.',
            'Relatos duplicados do mesmo problema podem inflar a contagem.',
          ],
          suggestedActions: [
            'Enviar equipe de vistoria para confirmar os relatos.',
            ..._actions(cat.relatedIndicatorId).take(2),
          ],
          generatedAt: now,
          affectedPopulation: max(people, 500),
        ),
      );
    });
    return alerts;
  }

  List<String> _baseLimitations(IndicatorSeries s, IndicatorAnalysis a) => [
    if (s.origin == DataOrigin.synthetic)
      'Dados sintéticos: cenário simulado para demonstração, não são '
          'medições reais.'
    else
      'Dados de modelo meteorológico (Open-Meteo, grade de ~11 km): '
          'podem não captar microclimas do bairro.',
    'Modelo estatístico simples (tendência linear + padrão semanal, '
        '28 dias): não considera feriados, obras ou intervenções.',
    'Indicador agregado do distrito: pode esconder desigualdades '
        'entre bairros.',
    ...a.reliabilityIssues,
  ];

  static int _daysBeyond(
    IndicatorSeries s,
    double limit,
    WorseDirection dir,
    int window,
  ) {
    final pts = s.points.length > window
        ? s.points.sublist(s.points.length - window)
        : s.points;
    return pts.where((p) {
      if (p.value == null) return false;
      return dir == WorseDirection.higher
          ? p.value! >= limit
          : p.value! <= limit;
    }).length;
  }

  static String _side(WorseDirection d) =>
      d == WorseDirection.higher ? 'acima' : 'abaixo';

  static String _dateKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  static List<String> _actions(String indicatorId) =>
      _suggestedActions[indicatorId] ??
      const ['Analisar o indicador com a equipe técnica responsável.'];

  static const _suggestedActions = <String, List<String>>{
    'water_consumption': [
      'Avaliar com a concessionária campanha de uso consciente de água.',
      'Verificar macromedidores para descartar vazamento de grande porte.',
      'Priorizar abastecimento de escolas, UBS e abrigos.',
    ],
    'water_loss': [
      'Programar varredura de vazamentos não visíveis nos setores críticos.',
      'Cruzar com relatos cidadãos de vazamento por bairro.',
    ],
    'energy_consumption': [
      'Alertar a distribuidora sobre risco de sobrecarga em horário de pico.',
      'Avaliar redução temporária de iluminação de prédios públicos ociosos.',
    ],
    'energy_outages': [
      'Acionar a distribuidora para inspeção da rede nos bairros afetados.',
      'Verificar pacientes eletrodependentes cadastrados na região.',
    ],
    'temp_max': [
      'Avaliar abertura de pontos de hidratação e acolhimento.',
      'Orientar UBS sobre atenção a idosos e crianças.',
      'Comunicar recomendações de calor extremo à população.',
    ],
    'precipitation': [
      'Avisar Defesa Civil e verificar limpeza de bocas de lobo.',
      'Monitorar áreas de várzea com histórico de alagamento.',
    ],
    'humidity_min': [
      'Divulgar orientações sobre hidratação e atividades ao ar livre.',
      'Avaliar suspensão de atividades físicas escolares no horário crítico.',
    ],
    'waste_collected': [
      'Verificar capacidade das rotas de coleta e frota disponível.',
      'Avaliar coleta extra nos bairros com maior volume.',
    ],
    'irregular_dumping': [
      'Programar mutirão de limpeza nos pontos recorrentes.',
      'Ampliar divulgação dos ecopontos mais próximos.',
    ],
    'recycling_rate': [
      'Reforçar campanha de coleta seletiva com cooperativas locais.',
      'Verificar regularidade da coleta seletiva por rota.',
    ],
    'health_visits': [
      'Avaliar remanejamento temporário de equipes entre UBS.',
      'Verificar se o aumento coincide com surto sazonal (ex.: respiratório).',
    ],
    'wait_time': [
      'Avaliar ampliação de horário ou triagem nas UBS mais demandadas.',
      'Divulgar canais de teleatendimento para casos leves.',
    ],
    'service_requests': [
      'Redistribuir equipes de zeladoria conforme demanda por bairro.',
      'Identificar tipos de solicitação que mais cresceram.',
    ],
  };
}
