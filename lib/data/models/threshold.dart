import 'indicator.dart';

/// Limiares de alerta configuráveis pelo gestor para um indicador.
class AlertThreshold {
  const AlertThreshold({
    required this.indicatorId,
    required this.warning,
    required this.critical,
    this.enabled = true,
  });

  final String indicatorId;
  final double warning;
  final double critical;
  final bool enabled;

  factory AlertThreshold.defaultFor(IndicatorDefinition d) => AlertThreshold(
    indicatorId: d.id,
    warning: d.defaultWarning,
    critical: d.defaultCritical,
  );

  AlertThreshold copyWith({double? warning, double? critical, bool? enabled}) =>
      AlertThreshold(
        indicatorId: indicatorId,
        warning: warning ?? this.warning,
        critical: critical ?? this.critical,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
    'indicatorId': indicatorId,
    'warning': warning,
    'critical': critical,
    'enabled': enabled,
  };

  factory AlertThreshold.fromJson(Map<String, dynamic> json) => AlertThreshold(
    indicatorId: json['indicatorId'] as String,
    warning: (json['warning'] as num).toDouble(),
    critical: (json['critical'] as num).toDouble(),
    enabled: json['enabled'] as bool? ?? true,
  );
}

/// Nível de um valor em relação ao limiar.
enum ThresholdLevel { normal, warning, critical }

extension ThresholdEvaluation on AlertThreshold {
  ThresholdLevel levelOf(double value, WorseDirection direction) {
    final worse = direction == WorseDirection.higher
        ? (double a, double b) => a >= b
        : (double a, double b) => a <= b;
    if (worse(value, critical)) return ThresholdLevel.critical;
    if (worse(value, warning)) return ThresholdLevel.warning;
    return ThresholdLevel.normal;
  }
}
