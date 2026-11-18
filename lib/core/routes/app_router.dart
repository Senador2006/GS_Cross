import 'package:material_ui/material_ui.dart';

import '../../ui/screens/alerts/alert_detail_screen.dart';
import '../../ui/screens/dashboard/dashboard_screen.dart';
import '../../ui/screens/home/home_shell.dart';
import '../../ui/screens/indicator/indicator_detail_screen.dart';
import '../../ui/screens/occurrences/occurrence_detail_screen.dart';
import '../../ui/screens/occurrences/occurrence_form_screen.dart';
import '../../ui/screens/onboarding/consent_screen.dart';
import '../../ui/screens/overview/social_impact_screen.dart';
import '../../ui/screens/settings/privacy_screen.dart';
import '../../ui/screens/settings/thresholds_screen.dart';
import '../../ui/screens/settings/transparency_screen.dart';
import 'app_routes.dart';

/// Fábrica central de rotas: resolve o nome + argumentos tipados.
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    Widget page;
    switch (settings.name) {
      case AppRoutes.onboarding:
        page = const ConsentScreen();
      case AppRoutes.home:
        page = HomeShell(initialTab: args is HomeArgs ? args.tab : 0);
      case AppRoutes.dashboard when args is DashboardArgs:
        page = DashboardScreen(domain: args.domain);
      case AppRoutes.indicator when args is IndicatorArgs:
        page = IndicatorDetailScreen(indicatorId: args.indicatorId);
      case AppRoutes.alert when args is AlertArgs:
        page = AlertDetailScreen(alertId: args.alertId);
      case AppRoutes.occurrenceNew:
        page = OccurrenceFormScreen(
          initialCategory: args is OccurrenceFormArgs ? args.category : null,
        );
      case AppRoutes.occurrence when args is OccurrenceArgs:
        page = OccurrenceDetailScreen(occurrenceId: args.occurrenceId);
      case AppRoutes.thresholds:
        page = ThresholdsScreen(
          focusIndicatorId: args is ThresholdsArgs
              ? args.focusIndicatorId
              : null,
        );
      case AppRoutes.privacy:
        page = const PrivacyScreen();
      case AppRoutes.transparency:
        page = const TransparencyScreen();
      case AppRoutes.impact:
        page = const SocialImpactScreen();
      default:
        page = _NotFound(name: settings.name);
    }
    return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Página não encontrada')),
    body: Center(
      child: Text(
        'A rota "${name ?? '?'}" não existe ou faltam '
        'parâmetros.',
      ),
    ),
  );
}
