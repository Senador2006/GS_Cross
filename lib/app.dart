import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/decision_repository.dart';
import 'data/repositories/occurrence_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/territory_repository.dart';
import 'data/services/ibge_api_service.dart';
import 'data/services/inmet_scraper_service.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/simulated_territory_api.dart';
import 'state/alerts_provider.dart';
import 'state/occurrences_provider.dart';
import 'state/settings_provider.dart';
import 'state/territory_provider.dart';

/// Raiz do app: injeção de dependências + tema + rotas.
class RadarTerritorialApp extends StatelessWidget {
  const RadarTerritorialApp({
    super.key,
    required this.storage,
    this.territoryApi,
    this.inmet,
    this.ibge,
  });

  final LocalStorageService storage;

  /// Injetáveis para testes.
  final SimulatedTerritoryApi? territoryApi;
  final InmetScraperService? inmet;
  final IbgeApiService? ibge;

  @override
  Widget build(BuildContext context) {
    final api = territoryApi ?? SimulatedTerritoryApi();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(SettingsRepository(storage), storage),
        ),
        ChangeNotifierProvider(
          create: (_) => TerritoryProvider(
            TerritoryRepository(
              territoryApi: api,
              inmet:
                  inmet ??
                  InmetScraperService(
                    localCsv: () => rootBundle.loadString(
                      InmetScraperService.localAsset,
                    ),
                  ),
              ibge: ibge ?? IbgeApiService(),
              storage: storage,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => OccurrencesProvider(
            OccurrenceRepository(storage: storage, api: api),
          ),
        ),
        ChangeNotifierProxyProvider3<
          TerritoryProvider,
          SettingsProvider,
          OccurrencesProvider,
          AlertsProvider
        >(
          create: (_) => AlertsProvider(DecisionRepository(storage)),
          update: (_, territory, settings, occurrences, alerts) =>
              alerts!..updateDependencies(territory, settings, occurrences),
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final prefs = settings.prefs;
    return MaterialApp(
      title: 'Radar Territorial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(highContrast: prefs.highContrast),
      darkTheme: AppTheme.dark(highContrast: prefs.highContrast),
      themeMode: prefs.themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: settings.hasValidConsent
          ? AppRoutes.home
          : AppRoutes.onboarding,
      // Uma única rota inicial (evita empilhar "/" antes de "/home").
      onGenerateInitialRoutes: (name) => [
        AppRouter.onGenerateRoute(RouteSettings(name: name)),
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        // Acessibilidade: a escala escolhida no app multiplica a do sistema,
        // respeitando quem já usa fonte grande no celular.
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(1);
        final scale = (systemScale * prefs.textScale).clamp(0.8, 2.4);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: prefs.reduceMotion || media.disableAnimations,
            highContrast: prefs.highContrast || media.highContrast,
          ),
          // fl_chart ainda importa package:flutter/material.dart; a ponte
          // repassa ThemeData/MaterialLocalizations até a lib migrar.
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(child: child!),
        );
      },
    );
  }
}
