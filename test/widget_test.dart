import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:radar_territorial/app.dart';
import 'package:radar_territorial/data/services/ibge_api_service.dart';
import 'package:radar_territorial/data/services/inmet_scraper_service.dart';
import 'package:radar_territorial/data/services/local_storage_service.dart';
import 'package:radar_territorial/data/services/simulated_territory_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await LocalStorageService.create();
  return RadarTerritorialApp(
    storage: storage,
    territoryApi: SimulatedTerritoryApi(latency: Duration.zero),
    inmet: InmetScraperService(
      client: MockClient((_) async => http.Response('erro', 503)),
    ),
    ibge: IbgeApiService(
      client: MockClient((_) async => http.Response('erro', 503)),
    ),
  );
}

const _consent = {
  'consent.v1':
      '{"version":1,"acceptedAt":"2026-11-18T10:00:00.000",'
      '"dataProcessing":true,"approximateLocation":false}',
};

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('sem consentimento abre onboarding e exige aceite', (
    tester,
  ) async {
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();
    expect(find.text('Consentimento (LGPD)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Aceitar e continuar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pump();
    expect(find.textContaining('é necessário aceitar'), findsOneWidget);
  });

  testWidgets('com consentimento carrega a visão geral e os dashboards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(prefs: _consent));
    await tester.pumpAndSettle();
    expect(find.text('Dashboards territoriais'), findsOneWidget);
    expect(find.text('Benefício social'), findsOneWidget);

    // Navega para um dashboard (rota nomeada com argumento).
    await tester.tap(find.text('Recursos'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard · Recursos'), findsOneWidget);
    expect(find.text('Histórico e previsão'), findsOneWidget);
  });

  testWidgets('formulário de ocorrência mostra erros de validação', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(prefs: _consent));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocorrências'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título *'),
      'abc',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição *'),
      'Ligue para 11 98765-4321 para saber mais',
    );
    await tester.scrollUntilVisible(
      find.text('Registrar ocorrência'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Registrar ocorrência'));
    await tester.pumpAndSettle();

    expect(find.text('Selecione a categoria da ocorrência.'), findsOneWidget);
    expect(find.textContaining('pelo menos 5'), findsOneWidget);
    expect(find.textContaining('Remova o telefone'), findsOneWidget);
  });

  testWidgets('limiar expandido mostra os campos sem erro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(prefs: _consent));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limiares de alerta'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tempo médio de espera'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tempo médio de espera'));
    await tester.pumpAndSettle();

    expect(find.text('Limiar de atenção *'), findsOneWidget);
    expect(find.text('Limiar crítico *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
