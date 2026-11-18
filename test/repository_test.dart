import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radar_territorial/core/constants/territory.dart';
import 'package:radar_territorial/data/models/indicator.dart';
import 'package:radar_territorial/data/repositories/territory_repository.dart';
import 'package:radar_territorial/data/services/api_exception.dart';
import 'package:radar_territorial/data/services/ibge_api_service.dart';
import 'package:radar_territorial/data/services/inmet_scraper_service.dart';
import 'package:radar_territorial/data/services/local_storage_service.dart';
import 'package:radar_territorial/data/services/simulated_territory_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _header =
    'Data;Hora UTC;PRECIPITAÇÃO TOTAL, HORÁRIO (mm);'
    'PRESSAO ATMOSFERICA AO NIVEL DA ESTACAO, HORARIA (mB);'
    'PRESSÃO ATMOSFERICA MAX.NA HORA ANT. (AUT) (mB);'
    'PRESSÃO ATMOSFERICA MIN. NA HORA ANT. (AUT) (mB);'
    'RADIACAO GLOBAL (Kj/m²);'
    'TEMPERATURA DO AR - BULBO SECO, HORARIA (°C);'
    'TEMPERATURA DO PONTO DE ORVALHO (°C);'
    'TEMPERATURA MÁXIMA NA HORA ANT. (AUT) (°C);'
    'TEMPERATURA MÍNIMA NA HORA ANT. (AUT) (°C);'
    'TEMPERATURA ORVALHO MAX. NA HORA ANT. (AUT) (°C);'
    'TEMPERATURA ORVALHO MIN. NA HORA ANT. (AUT) (°C);'
    'UMIDADE REL. MAX. NA HORA ANT. (AUT) (%);'
    'UMIDADE REL. MIN. NA HORA ANT. (AUT) (%);'
    'UMIDADE RELATIVA DO AR, HORARIA (%);'
    'VENTO, DIREÇÃO HORARIA (gr) (° (gr));'
    'VENTO, RAJADA MAXIMA (m/s);'
    'VENTO, VELOCIDADE HORARIA (m/s);';

const _stationCsv = '''
REGIAO:;SE
ESTACAO:;SAO PAULO - MIRANTE
CODIGO (WMO):;A701
$_header
2026/10/31;0000 UTC;0;924,7;924,7;924,3;;25,1;16,2;25,4;24,9;17,2;16,1;61;58;58;306;7;2,6;
2026/10/31;0100 UTC;1,5;924,7;924,7;924,3;;26,0;16,2;28,0;24,9;17,2;16,1;61;40;58;306;7;2,6;
2026/10/31;0200 UTC;;924,7;924,7;924,3;;26,0;16,2;9999;24,9;17,2;16,1;61;;58;306;7;2,6;
2026/11/01;0000 UTC;0;924,7;924,7;924,3;;20,0;16,2;;24,9;17,2;16,1;61;50;58;306;7;2,6;
''';

const _pageHtml = '''
<html><body>
<a href="https://portal.inmet.gov.br/uploads/dadoshistoricos/2025.zip">2025</a>
<a href="https://portal.inmet.gov.br/uploads/dadoshistoricos/2026.zip">2026</a>
</body></html>
''';

const _localityJson =
    '[{"id":355030837,"nome":"Itaquera","municipio":{"id":3550308,"nome":"São Paulo"}}]';

const _populationJson =
    '[{"id":"93","variavel":"População residente","unidade":"Pessoas",'
    '"resultados":[{"classificacoes":[],"series":[{"localidade":'
    '{"id":"355030837","nivel":{"id":"N10","nome":"Distrito"},'
    '"nome":"Itaquera - São Paulo (SP)"},"serie":{"2010":"204871"}}]}]}]';

void main() {
  late LocalStorageService storage;
  late Uint8List zipBytes;
  final api = SimulatedTerritoryApi(latency: Duration.zero);
  final clock = DateTime(2026, 11, 17);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.create();
    final rows = StringBuffer(
      'Data;Hora UTC;PRECIPITAÇÃO TOTAL, HORÁRIO (mm);'
      'TEMPERATURA MÁXIMA NA HORA ANT. (AUT) (°C);'
      'UMIDADE REL. MIN. NA HORA ANT. (AUT) (%)\n',
    );
    for (var day = 1; day <= 20; day++) {
      final label = day.toString().padLeft(2, '0');
      rows.writeln('2026/10/$label;1200 UTC;0,4;31,0;42');
    }
    final archive = Archive();
    archive.addFile(
      ArchiveFile.bytes(
        'INMET_SE_SP_A701_SAO PAULO - MIRANTE_01-01-2026_A_31-10-2026.CSV',
        latin1.encode(rows.toString()),
      ),
    );
    zipBytes = ZipEncoder().encodeBytes(archive);
  });

  InmetScraperService inmet({bool fail = false}) => InmetScraperService(
    clock: () => clock,
    client: MockClient(
      (request) async => fail
          ? http.Response('indisponivel', 503)
          : _serve(request, zipBytes),
    ),
  );

  IbgeApiService ibge({bool fail = false}) => IbgeApiService(
    client: MockClient((request) async {
      if (fail) return http.Response('indisponivel', 503);
      final body = request.url.path.contains('localidades')
          ? _localityJson
          : _populationJson;
      return http.Response(body, 200);
    }),
  );

  TerritoryRepository repo({bool inmetDown = false, bool ibgeDown = false}) =>
      TerritoryRepository(
        territoryApi: api,
        inmet: inmet(fail: inmetDown),
        ibge: ibge(fail: ibgeDown),
        storage: storage,
        clock: () => clock,
      );

  test('página do INMET: o HTML aponta o ZIP do ano', () {
    final urls = InmetScraperService.scrapeZipUrls(_pageHtml, {2026});
    expect(urls.keys, {2026});
    expect(
      urls[2026].toString(),
      'https://portal.inmet.gov.br/uploads/dadoshistoricos/2026.zip',
    );
  });

  test('CSV da estação: agrega o dia e trata buraco e 9999', () {
    final series = InmetScraperService.seriesFromCsv(
      _stationCsv,
      DateTime(2026, 11, 17),
    );
    final temp = series.first;
    final rain = series[1];
    final humid = series[2];
    expect(temp.origin, DataOrigin.publicApi);
    expect(temp.points, hasLength(Territory.historyDays));

    final oct31 = DateTime(2026, 10, 31);
    expect(temp.points.firstWhere((p) => p.date == oct31).value, 28);
    expect(rain.points.firstWhere((p) => p.date == oct31).value, 1.5);
    expect(humid.points.firstWhere((p) => p.date == oct31).value, 40);

    final nov1 = DateTime(2026, 11, 1);
    expect(temp.points.firstWhere((p) => p.date == nov1).value, isNull);
    expect(humid.points.firstWhere((p) => p.date == nov1).value, 50);
  });

  test('IBGE: interpreta distrito e população do Censo', () async {
    final census = await ibge().fetchDistrict();
    expect(census.name, 'Itaquera');
    expect(census.municipality, 'São Paulo');
    expect(census.population, 204871);
    expect(census.censusYear, 2010);
    expect(census.note, contains('204.871'));
  });

  test('online: combina INMET, IBGE e grava cache', () async {
    final repository = repo();
    final snap = await repository.load();
    expect(snap.fromCache, isFalse);
    expect(snap.series, hasLength(13));
    expect(snap.byId('temp_max')!.origin, DataOrigin.publicApi);
    expect(snap.population, 204871);
    expect(snap.notes, isNotEmpty);
    expect(snap.warnings, isEmpty);
    expect(repository.readCache(), isNotNull);
  });

  test('INMET fora do ar: clima sintético com aviso', () async {
    final snap = await repo(inmetDown: true).load();
    expect(snap.warnings, isNotEmpty);
    expect(snap.byId('temp_max')!.origin, DataOrigin.synthetic);
    expect(snap.population, 204871);
  });

  test('IBGE fora do ar: mantém a população de referência', () async {
    final snap = await repo(ibgeDown: true).load();
    expect(snap.population, Territory.population);
    expect(
      snap.warnings.any((w) => w.contains('valor de referência')),
      isTrue,
    );
    expect(snap.byId('temp_max')!.origin, DataOrigin.publicApi);
  });

  test('offline com cache: devolve dados salvos marcados como cache', () async {
    final repository = repo();
    await repository.load();
    final offline = await repository.load(offline: true);
    expect(offline.fromCache, isTrue);
    expect(offline.series, hasLength(13));
  });

  test('offline sem cache: propaga erro', () async {
    expect(() => repo().load(offline: true), throwsA(isA<ApiException>()));
  });

  test('API simulada é determinística', () {
    final def = IndicatorCatalog.byId('wait_time');
    final fixed = DateTime(2026, 11, 18);
    final a = SimulatedTerritoryApi(clock: () => fixed).generate(def);
    final b = SimulatedTerritoryApi(clock: () => fixed).generate(def);
    expect(a.points.map((p) => p.value), b.points.map((p) => p.value));
    expect(a.points.last.isMissing, isFalse);
  });
}

http.Response _serve(http.Request request, Uint8List zipBytes) {
  final url = request.url.toString();
  if (url.contains('dadoshistoricos') && !url.endsWith('.zip')) {
    return http.Response(_pageHtml, 200);
  }
  if (!url.endsWith('.zip')) return http.Response('nao encontrado', 404);

  final header = request.headers['range'] ?? '';
  final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(header);
  if (match == null) return http.Response('faixa ausente', 400);
  final start = int.parse(match.group(1)!);
  final end = int.parse(match.group(2)!);
  final slice = zipBytes.sublist(start, end + 1);
  return http.Response.bytes(
    slice,
    206,
    headers: {'content-range': 'bytes $start-$end/${zipBytes.length}'},
  );
}
