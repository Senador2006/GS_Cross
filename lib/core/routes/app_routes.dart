import '../../data/models/indicator.dart';
import '../../data/models/occurrence.dart';

/// Rotas nomeadas do app.
class AppRoutes {
  AppRoutes._();

  static const onboarding = '/onboarding';
  static const home = '/home';
  static const dashboard = '/dashboard';
  static const indicator = '/indicator';
  static const alert = '/alert';
  static const occurrenceNew = '/occurrence/new';
  static const occurrence = '/occurrence';
  static const thresholds = '/settings/thresholds';
  static const privacy = '/settings/privacy';
  static const transparency = '/about/model';
  static const impact = '/impact';
}

// ---------------------------------------------------------------------------
// Argumentos tipados — evitam passar `Map`s sem contrato entre telas.
// ---------------------------------------------------------------------------

class HomeArgs {
  const HomeArgs({this.tab = 0});
  final int tab;
}

class DashboardArgs {
  const DashboardArgs(this.domain);
  final TerritoryDomain domain;
}

class IndicatorArgs {
  const IndicatorArgs(this.indicatorId);
  final String indicatorId;
}

class AlertArgs {
  const AlertArgs(this.alertId);
  final String alertId;
}

class OccurrenceFormArgs {
  const OccurrenceFormArgs({this.category});
  final OccurrenceCategory? category;
}

class OccurrenceArgs {
  const OccurrenceArgs(this.occurrenceId);
  final String occurrenceId;
}

class ThresholdsArgs {
  const ThresholdsArgs({this.focusIndicatorId});
  final String? focusIndicatorId;
}
