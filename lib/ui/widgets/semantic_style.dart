import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/alert.dart';
import '../../data/models/analysis.dart';
import '../../data/models/indicator.dart';
import '../../data/models/threshold.dart';

/// Mapeia conceitos de domínio para cores e ícones consistentes,
/// adaptados ao brilho do tema (claro/escuro). Cor nunca é o único
/// portador de significado: sempre há ícone e/ou texto junto.
class SemanticStyle {
  SemanticStyle._();

  static bool _dark(BuildContext c) =>
      Theme.of(c).colorScheme.brightness == Brightness.dark;

  static Color severity(BuildContext c, AlertSeverity s) {
    final dark = _dark(c);
    return switch (s) {
      AlertSeverity.critical =>
        dark ? AppColors.criticalOnDark : AppColors.critical,
      AlertSeverity.warning =>
        dark ? AppColors.warningOnDark : AppColors.warning,
      AlertSeverity.info => dark ? AppColors.infoOnDark : AppColors.info,
    };
  }

  static IconData severityIcon(AlertSeverity s) => switch (s) {
    AlertSeverity.critical => Icons.report_rounded,
    AlertSeverity.warning => Icons.warning_amber_rounded,
    AlertSeverity.info => Icons.info_outline_rounded,
  };

  static Color level(BuildContext c, ThresholdLevel l) => switch (l) {
    ThresholdLevel.critical => severity(c, AlertSeverity.critical),
    ThresholdLevel.warning => severity(c, AlertSeverity.warning),
    ThresholdLevel.normal =>
      _dark(c) ? AppColors.successOnDark : AppColors.success,
  };

  static String levelLabel(ThresholdLevel l) => switch (l) {
    ThresholdLevel.critical => 'Crítico',
    ThresholdLevel.warning => 'Atenção',
    ThresholdLevel.normal => 'Normal',
  };

  static Color confidence(BuildContext c, ConfidenceLevel l) => switch (l) {
    ConfidenceLevel.high =>
      _dark(c) ? AppColors.successOnDark : AppColors.success,
    ConfidenceLevel.medium =>
      _dark(c) ? AppColors.warningOnDark : AppColors.warning,
    ConfidenceLevel.low =>
      _dark(c) ? AppColors.criticalOnDark : AppColors.critical,
  };

  static Color decision(BuildContext c, DecisionStatus s) {
    final scheme = Theme.of(c).colorScheme;
    return switch (s) {
      DecisionStatus.pending => scheme.onSurfaceVariant,
      DecisionStatus.acknowledged =>
        _dark(c) ? AppColors.infoOnDark : AppColors.info,
      DecisionStatus.forwarded => scheme.primary,
      DecisionStatus.resolved =>
        _dark(c) ? AppColors.successOnDark : AppColors.success,
      DecisionStatus.dismissed => scheme.outline,
    };
  }

  static IconData decisionIcon(DecisionStatus s) => switch (s) {
    DecisionStatus.pending => Icons.hourglass_top_rounded,
    DecisionStatus.acknowledged => Icons.visibility_rounded,
    DecisionStatus.forwarded => Icons.send_rounded,
    DecisionStatus.resolved => Icons.task_alt_rounded,
    DecisionStatus.dismissed => Icons.do_not_disturb_on_outlined,
  };

  static Color domain(BuildContext c, TerritoryDomain d) {
    final base = AppColors.domain[d.name]!;
    return _dark(c) ? Color.lerp(base, Colors.white, 0.45)! : base;
  }

  static IconData domainIcon(TerritoryDomain d) => switch (d) {
    TerritoryDomain.resources => Icons.water_drop_rounded,
    TerritoryDomain.climate => Icons.thermostat_rounded,
    TerritoryDomain.waste => Icons.recycling_rounded,
    TerritoryDomain.services => Icons.local_hospital_rounded,
  };

  static IconData trendIcon(TrendDirection t) => switch (t) {
    TrendDirection.up => Icons.trending_up_rounded,
    TrendDirection.down => Icons.trending_down_rounded,
    TrendDirection.stable => Icons.trending_flat_rounded,
  };

  /// Tendência é "ruim" se vai na direção em que o indicador piora.
  static Color trend(BuildContext c, TrendDirection t, WorseDirection worse) {
    if (t == TrendDirection.stable) {
      return Theme.of(c).colorScheme.onSurfaceVariant;
    }
    final bad = (t == TrendDirection.up) == (worse == WorseDirection.higher);
    return bad
        ? severity(c, AlertSeverity.critical)
        : (_dark(c) ? AppColors.successOnDark : AppColors.success);
  }
}
