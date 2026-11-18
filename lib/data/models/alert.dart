import 'analysis.dart';

enum AlertSeverity {
  critical('Crítico', 3),
  warning('Atenção', 2),
  info('Informativo', 1);

  const AlertSeverity(this.label, this.weight);
  final String label;
  final int weight;
}

enum AlertKind {
  thresholdBreach('Limiar ultrapassado'),
  predictedBreach('Previsão de ultrapassagem'),
  anomaly('Anomalia estatística'),
  trend('Tendência persistente'),
  citizenReports('Aumento de relatos cidadãos');

  const AlertKind(this.label);
  final String label;
}

/// Alerta preditivo gerado pelo [AlertEngine].
///
/// Todo alerta carrega a evidência que o originou, o nível de confiança e
/// as limitações conhecidas — a decisão sobre o que fazer é sempre humana.
class TerritoryAlert {
  const TerritoryAlert({
    required this.id,
    required this.indicatorId,
    required this.kind,
    required this.severity,
    required this.title,
    required this.summary,
    required this.evidence,
    required this.confidenceScore,
    required this.limitations,
    required this.suggestedActions,
    required this.generatedAt,
    required this.affectedPopulation,
    this.expectedDate,
  });

  /// Determinístico (indicador + tipo + data) para que a decisão humana
  /// persistida continue associada ao mesmo alerta entre sessões.
  final String id;
  final String indicatorId;
  final AlertKind kind;
  final AlertSeverity severity;
  final String title;
  final String summary;
  final List<String> evidence;
  final double confidenceScore;
  final List<String> limitations;
  final List<String> suggestedActions;
  final DateTime generatedAt;
  final int affectedPopulation;

  /// Para alertas de previsão: data em que o limiar deve ser atingido.
  final DateTime? expectedDate;

  ConfidenceLevel get confidence => ConfidenceLevel.fromScore(confidenceScore);
}

/// Status da avaliação humana de um alerta.
enum DecisionStatus {
  pending('Aguardando avaliação'),
  acknowledged('Em acompanhamento'),
  forwarded('Encaminhado à equipe'),
  resolved('Resolvido'),
  dismissed('Descartado (falso positivo)');

  const DecisionStatus(this.label);
  final String label;

  /// Decisões que geram benefício social (ação efetiva sobre o alerta).
  bool get isActioned =>
      this == acknowledged || this == forwarded || this == resolved;
}

/// Registro da decisão humana sobre um alerta (persistido localmente).
class AlertDecision {
  const AlertDecision({
    required this.alertId,
    required this.status,
    required this.note,
    required this.decidedAt,
    required this.alertGeneratedAt,
  });

  final String alertId;
  final DecisionStatus status;
  final String note;
  final DateTime decidedAt;
  final DateTime alertGeneratedAt;

  Duration get responseTime => decidedAt.difference(alertGeneratedAt);

  Map<String, dynamic> toJson() => {
    'alertId': alertId,
    'status': status.name,
    'note': note,
    'decidedAt': decidedAt.toIso8601String(),
    'alertGeneratedAt': alertGeneratedAt.toIso8601String(),
  };

  factory AlertDecision.fromJson(Map<String, dynamic> json) => AlertDecision(
    alertId: json['alertId'] as String,
    status: DecisionStatus.values.byName(json['status'] as String),
    note: json['note'] as String? ?? '',
    decidedAt: DateTime.parse(json['decidedAt'] as String),
    alertGeneratedAt: DateTime.parse(json['alertGeneratedAt'] as String),
  );
}
