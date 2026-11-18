import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/territory.dart';
import '../models/data_point.dart';
import '../models/indicator.dart';
import 'api_exception.dart';

/// Cliente da API pública Open-Meteo (https://open-meteo.com), gratuita,
/// sem chave de acesso e licenciada sob CC BY 4.0.
///
/// Busca o histórico diário recente de temperatura máxima, precipitação e
/// umidade mínima para as coordenadas do território.
class ClimateApiService {
  ClimateApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  Uri buildUri() => Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '${Territory.latitude}',
    'longitude': '${Territory.longitude}',
    'daily': 'temperature_2m_max,precipitation_sum,relative_humidity_2m_min',
    'past_days': '${Territory.historyDays}',
    'forecast_days': '1',
    'timezone': Territory.timezone,
  });

  Future<List<IndicatorSeries>> fetchClimate() async {
    final http.Response response;
    try {
      response = await _client.get(buildUri()).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao consultar a Open-Meteo.',
        isConnectivity: true,
      );
    } catch (_) {
      throw const ApiException(
        'Sem conexão com a Open-Meteo.',
        isConnectivity: true,
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Open-Meteo respondeu com status ${response.statusCode}.',
      );
    }
    try {
      return parse(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      throw ApiException('Resposta inesperada da Open-Meteo: $e');
    }
  }

  /// Converte o JSON da Open-Meteo em séries. Exposto para testes.
  static List<IndicatorSeries> parse(Map<String, dynamic> json) {
    final daily = json['daily'] as Map<String, dynamic>;
    final dates = (daily['time'] as List)
        .cast<String>()
        .map(DateTime.parse)
        .toList();

    List<DataPoint> pointsFor(String key) {
      final values = daily[key] as List;
      return [
        for (var i = 0; i < dates.length; i++)
          DataPoint(date: dates[i], value: (values[i] as num?)?.toDouble()),
      ];
    }

    IndicatorSeries series(String id, String key) => IndicatorSeries(
      definition: IndicatorCatalog.byId(id),
      points: pointsFor(key),
      origin: DataOrigin.publicApi,
    );

    return [
      series('temp_max', 'temperature_2m_max'),
      series('precipitation', 'precipitation_sum'),
      series('humidity_min', 'relative_humidity_2m_min'),
    ];
  }
}
