import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Distrito de Itaquera e população residente no Censo, pela API do IBGE.
///
/// Localidade: serviço de localidades. População: agregado 1378
/// (Censo Demográfico 2010), nível N10 (distrito), totais de sexo, idade,
/// situação e condição no domicílio. O Censo 2022 ainda não publica
/// esse recorte de distrito nessa API.
class IbgeApiService {
  IbgeApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const districtId = 355030837;
  static const _timeout = Duration(seconds: 15);
  static const _userAgent = 'RadarTerritorial/1.0 (uso academico)';

  Uri get localityUri => Uri.https(
    'servicodados.ibge.gov.br',
    '/api/v1/localidades/distritos/$districtId',
  );

  /// Totais (categoria 0) para não estourar o cruzamento da tabela.
  Uri get populationUri => Uri.https(
    'servicodados.ibge.gov.br',
    '/api/v3/agregados/1378/periodos/2010/variaveis/93',
    {
      'localidades': 'N10[$districtId]',
      'classificacao': '1[0]|2[0]|287[0]|455[0]',
    },
  );

  Future<DistrictCensus> fetchDistrict() async {
    // Em sequência: se as duas correm juntas e a primeira falha, o erro da
    // segunda escapa antes de ser aguardado.
    final locality = _parseLocality(await _get(localityUri));
    final population = _parsePopulation(await _get(populationUri));
    if (locality.id != districtId || population.id != districtId) {
      throw const ApiException(
        'O IBGE não devolveu o distrito de Itaquera.',
      );
    }
    return DistrictCensus(
      id: locality.id,
      name: locality.name,
      municipality: locality.municipality,
      population: population.population,
      censusYear: population.year,
    );
  }

  static _Locality _parseLocality(Object? json) {
    if (json is! List || json.isEmpty) {
      throw const ApiException('Resposta inesperada da localidade do IBGE.');
    }
    final item = json.first;
    if (item is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da localidade do IBGE.');
    }
    final municipality = item['municipio'];
    if (municipality is! Map) {
      throw const ApiException('Resposta inesperada da localidade do IBGE.');
    }
    return _Locality(
      id: item['id'] as int,
      name: item['nome'] as String,
      municipality: municipality['nome'] as String,
    );
  }

  static _Population _parsePopulation(Object? json) {
    if (json is! List || json.isEmpty) {
      throw const ApiException('Resposta inesperada da população do IBGE.');
    }
    final root = json.first;
    if (root is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da população do IBGE.');
    }
    final results = root['resultados'];
    if (results is! List || results.isEmpty) {
      throw const ApiException('O IBGE não informou a população do distrito.');
    }
    final series = (results.first as Map<String, dynamic>)['series'];
    if (series is! List || series.isEmpty) {
      throw const ApiException('O IBGE não informou a população do distrito.');
    }
    final item = series.first as Map<String, dynamic>;
    final place = item['localidade'] as Map<String, dynamic>;
    final values = item['serie'] as Map<String, dynamic>;
    if (values.isEmpty) {
      throw const ApiException('O IBGE não informou a população do distrito.');
    }
    final year = values.keys.first;
    return _Population(
      id: int.parse(place['id'] as String),
      year: int.parse(year),
      population: int.parse(values[year] as String),
    );
  }

  Future<Object?> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao consultar o IBGE.',
        isConnectivity: true,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(
        'Sem conexão com o IBGE.',
        isConnectivity: true,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'O IBGE respondeu com status ${response.statusCode}.',
      );
    }
    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw ApiException('Resposta inesperada do IBGE: $e');
    }
  }
}

class DistrictCensus {
  const DistrictCensus({
    required this.id,
    required this.name,
    required this.municipality,
    required this.population,
    required this.censusYear,
  });

  final int id;
  final String name;
  final String municipality;
  final int population;
  final int censusYear;

  String get note =>
      'População de $name ($municipality): ${_thousands(population)} '
      'habitantes (IBGE, Censo $censusYear).';
}

class _Locality {
  const _Locality({
    required this.id,
    required this.name,
    required this.municipality,
  });

  final int id;
  final String name;
  final String municipality;
}

class _Population {
  const _Population({
    required this.id,
    required this.year,
    required this.population,
  });

  final int id;
  final int year;
  final int population;
}

String _thousands(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
    buffer.write(text[i]);
  }
  return buffer.toString();
}
