import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radar_territorial/core/constants/territory.dart';
import 'package:radar_territorial/data/models/indicator.dart';
import 'package:radar_territorial/data/repositories/territory_repository.dart';
import 'package:radar_territorial/data/services/api_exception.dart';
import 'package:radar_territorial/data/services/climate_api_service.dart';
import 'package:radar_territorial/data/services/local_storage_service.dart';
import 'package:radar_territorial/data/services/simulated_territory_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _openMeteoJson = '''
{"daily": {
  "time": ["2026-11-16", "2026-11-17", "2026-11-18"],
  "temperature_2m_max": [28.1, 30.4, null],
  "precipitation_sum": [0.0, 12.5, 3.1],
  "relative_humidity_2m_min": [45, 38, 41]
}}
''';

void main() {
  late LocalStorageService storage;
  final api = SimulatedTerritoryApi(latency: Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
  });

  ClimateApiService climate({bool fail = false}) => ClimateApiService(
    client: MockClient(
      (_) async => fail
          ? throw const ApiException('rede', isConnectivity: true)
          : http.Response(_openMeteoJson, 200),
    ),
  );

  test('Open-Meteo: parse converte nulos em dados faltantes', () {
    final series = ClimateApiService.parse({
      'daily': {
        'time': ['2026-11-17', '2026-11-18'],
        'temperature_2m_max': [30.0, null],
        'precipitation_sum': [1.0, 2.0],
        'relative_humidity_2m_min': [40, 50],
      },
    });
    expect(series, hasLength(3));
    expect(series.first.points.last.isMissing, isTrue);
    expect(series.first.origin, DataOrigin.publicApi);
  });

  test('online: combina fontes e grava cache', () async {
    final repo = TerritoryRepository(
      territoryApi: api,
      climateApi: climate(),
      storage: storage,
    );
    final snap = await repo.load();
    expect(snap.fromCache, isFalse);
    expect(snap.series.length, 13);
    expect(repo.readCache(), isNotNull);
  });

  test('Open-Meteo fora do ar: clima sintético com aviso', () async {
    final repo = TerritoryRepository(
      territoryApi: api,
      climateApi: climate(fail: true),
      storage: storage,
    );
    final snap = await repo.load();
    expect(snap.warnings, isNotEmpty);
    expect(snap.byId('temp_max')!.origin, DataOrigin.synthetic);
  });

  test('offline com cache: devolve dados salvos marcados como cache', () async {
    final repo = TerritoryRepository(
      territoryApi: api,
      climateApi: climate(),
      storage: storage,
    );
    await repo.load();
    final offline = await repo.load(offline: true);
    expect(offline.fromCache, isTrue);
    expect(offline.series.length, 13);
  });

  test('offline sem cache: propaga erro', () async {
    final repo = TerritoryRepository(
      territoryApi: api,
      climateApi: climate(),
      storage: storage,
    );
    expect(() => repo.load(offline: true), throwsA(isA<ApiException>()));
  });

  test('API simulada é determinística', () {
    final def = IndicatorCatalog.byId('wait_time');
    final clock = DateTime(2026, 11, 18);
    final a = SimulatedTerritoryApi(clock: () => clock).generate(def);
    final b = SimulatedTerritoryApi(clock: () => clock).generate(def);
    expect(a.points.map((p) => p.value), b.points.map((p) => p.value));
    expect(a.points.last.isMissing, isFalse);
  });
}
