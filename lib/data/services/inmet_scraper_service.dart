import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/territory.dart';
import '../models/data_point.dart';
import '../models/indicator.dart';
import 'api_exception.dart';

/// Clima lido da página pública de dados históricos do INMET.
///
/// A tabela em tempo.inmet.gov.br é uma aplicação JavaScript que só entrega
/// a série depois de um reCAPTCHA. Esta classe não contorna essa verificação:
/// ela lê o HTML de [pageUri], segue o link do arquivo do ano e, dentro do
/// ZIP, busca só a estação automática mais próxima de Itaquera.
class InmetScraperService {
  InmetScraperService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;

  static const pageUri = 'https://portal.inmet.gov.br/dadoshistoricos';

  /// São Paulo - Mirante de Santana. Itaquera não tem estação do INMET;
  /// esta é a automática mais próxima (~18 km).
  static const stationCode = 'A701';
  static const stationName = 'São Paulo - Mirante de Santana';

  static const _userAgent = 'RadarTerritorial/1.0 (uso academico)';
  static const _timeout = Duration(seconds: 20);
  static const _tailBytes = 262144;

  Uri get page => Uri.parse(pageUri);

  Future<InmetClimate> fetchClimate() async {
    final today = _dateOnly(_clock());
    final start = today.subtract(
      Duration(days: Territory.historyDays - 1),
    );
    final years = {for (var y = start.year; y <= today.year; y++) y};

    final html = await _getText(page);
    final zips = scrapeZipUrls(html, years);
    final missing = years.where((year) => !zips.containsKey(year));
    if (missing.isNotEmpty) {
      throw ApiException(
        'A página do INMET não publicou o arquivo de ${missing.join(', ')}.',
      );
    }

    final daily = <DateTime, _Day>{};
    for (final year in years.toList()..sort()) {
      final csv = await _stationCsv(zips[year]!);
      daily.addAll(_parseHourlyCsv(csv));
    }

    final series = _buildSeries(daily, today);
    final valid = series.first.points.where((p) => !p.isMissing).length;
    if (valid < 14) {
      throw const ApiException(
        'A estação do INMET não tem dias suficientes no período.',
      );
    }

    DateTime? last;
    for (final point in series.first.points) {
      if (!point.isMissing) last = point.date;
    }

    final until = last == null ? '' : ' O arquivo vai até ${_dmy(last)}.';
    return InmetClimate(
      series: series,
      note:
          'Clima da estação $stationCode ($stationName), '
          'a mais próxima de Itaquera.$until',
    );
  }

  /// Links `dadoshistoricos/ANO.zip` publicados no HTML da página.
  static Map<int, Uri> scrapeZipUrls(String html, Set<int> years) {
    final pattern = RegExp(
      "href=[\"']([^\"']*dadoshistoricos/(\\d{4})\\.zip)[\"']",
      caseSensitive: false,
    );
    final found = <int, Uri>{};
    for (final match in pattern.allMatches(html)) {
      final year = int.parse(match.group(2)!);
      if (!years.contains(year)) continue;
      found[year] = _resolve(match.group(1)!);
    }
    return found;
  }

  /// Agrega o CSV horário da estação na série diária do app.
  static List<IndicatorSeries> seriesFromCsv(String csv, DateTime today) =>
      _buildSeries(_parseHourlyCsv(csv), today);

  /// Agrega as horas do CSV da estação em um valor por dia.
  static Map<DateTime, _Day> _parseHourlyCsv(String csv) {
    final lines = const LineSplitter().convert(csv);
    var headerAt = -1;
    for (var i = 0; i < lines.length; i++) {
      final first = lines[i].split(';').first.trim().toUpperCase();
      if (first == 'DATA') {
        headerAt = i;
        break;
      }
    }
    if (headerAt < 0) {
      throw const ApiException('CSV da estação do INMET sem cabeçalho.');
    }

    final headers = lines[headerAt].split(';');
    final precip = _column(headers, (h) => h.contains('PRECIPITA'));
    final tempMax = _column(
      headers,
      (h) =>
          h.contains('TEMPERATURA') &&
          h.contains('XIMA') &&
          !h.contains('ORVALHO'),
    );
    final humidMin = _column(
      headers,
      (h) => h.contains('UMIDADE') && h.contains('MIN'),
    );
    if (precip == null || tempMax == null || humidMin == null) {
      throw const ApiException(
        'CSV da estação do INMET não tem chuva, temperatura ou umidade.',
      );
    }

    final days = <DateTime, _Day>{};
    for (final line in lines.skip(headerAt + 1)) {
      if (line.trim().isEmpty) continue;
      final cells = line.split(';');
      final date = _parseDate(cells.first);
      if (date == null) continue;
      final day = days.putIfAbsent(date, _Day.new);
      day.add(
        tempMax: _cell(cells, tempMax),
        precip: _cell(cells, precip),
        humidMin: _cell(cells, humidMin),
      );
    }
    return days;
  }

  /// Série diária dos últimos [Territory.historyDays], com buraco onde
  /// a estação não mediu.
  static List<IndicatorSeries> _buildSeries(
    Map<DateTime, _Day> days,
    DateTime today,
  ) {
    final dates = [
      for (var i = Territory.historyDays - 1; i >= 0; i--)
        today.subtract(Duration(days: i)),
    ];

    IndicatorSeries series(
      String id,
      double? Function(_Day? day) value,
    ) => IndicatorSeries(
      definition: IndicatorCatalog.byId(id),
      origin: DataOrigin.publicApi,
      points: [
        for (final date in dates)
          DataPoint(date: date, value: value(days[date])),
      ],
    );

    return [
      series('temp_max', (day) => day?.tempMax),
      series('precipitation', (day) => day?.precip),
      series('humidity_min', (day) => day?.humidMin),
    ];
  }

  Future<String> _stationCsv(Uri zipUrl) async {
    final head = await _range(zipUrl, 0, 0);
    final length = head.total;
    if (length < 22) {
      throw const ApiException('Arquivo do INMET veio vazio.');
    }

    final tailStart = math.max(0, length - _tailBytes);
    final tail = tailStart == 0
        ? head.bytes.length == length
              ? head
              : await _range(zipUrl, 0, length - 1)
        : await _range(zipUrl, tailStart, length - 1);

    final eocd = _findEocd(tail.bytes, tailStart, length);
    if (eocd < 0) {
      throw const ApiException(
        'Não foi possível localizar o índice do arquivo do INMET.',
      );
    }
    final view = ByteData.sublistView(tail.bytes);
    final cdSize = view.getUint32(eocd + 12, Endian.little);
    final cdOffset = view.getUint32(eocd + 16, Endian.little);
    if (cdSize == 0xffffffff || cdOffset == 0xffffffff) {
      throw const ApiException('O arquivo do INMET está em um formato ZIP64.');
    }

    final Uint8List central;
    if (cdOffset >= tailStart && cdOffset + cdSize <= length) {
      final local = cdOffset - tailStart;
      central = Uint8List.sublistView(tail.bytes, local, local + cdSize);
    } else {
      final fetched = await _range(zipUrl, cdOffset, cdOffset + cdSize - 1);
      central = fetched.bytes;
    }

    final entry = _findStation(central);
    final localHeader = await _range(zipUrl, entry.offset, entry.offset + 29);
    if (localHeader.bytes.length < 30) {
      throw const ApiException('Cabeçalho da estação do INMET está incompleto.');
    }
    final local = ByteData.sublistView(localHeader.bytes);
    final nameLen = local.getUint16(26, Endian.little);
    final extraLen = local.getUint16(28, Endian.little);
    final dataStart = entry.offset + 30 + nameLen + extraLen;
    final payload = await _range(
      zipUrl,
      dataStart,
      dataStart + entry.compressedSize - 1,
    );

    final raw = switch (entry.method) {
      0 => payload.bytes,
      8 => Inflate(
        payload.bytes,
        uncompressedSize: entry.uncompressedSize,
        throwOnError: true,
      ).getBytes(),
      _ => throw ApiException(
        'Compactação ${entry.method} do INMET não é suportada.',
      ),
    };
    return latin1.decode(raw);
  }

  Future<String> _getText(Uri uri) async {
    final response = await _send(uri);
    if (response.statusCode != 200) {
      throw ApiException(
        'A página do INMET respondeu com status ${response.statusCode}.',
      );
    }
    return response.body;
  }

  Future<_Range> _range(Uri uri, int start, int end) async {
    final response = await _send(uri, headers: {'Range': 'bytes=$start-$end'});
    final asked = end - start + 1;
    if (response.statusCode == 200 && response.bodyBytes.length > asked) {
      throw const ApiException(
        'O INMET não permitiu ler só a estação dentro do arquivo.',
      );
    }
    if (response.statusCode != 206 && response.statusCode != 200) {
      throw ApiException(
        'Arquivo do INMET respondeu com status ${response.statusCode}.',
      );
    }
    final total = _contentRangeTotal(response) ?? response.bodyBytes.length;
    return _Range(response.bodyBytes, total);
  }

  Future<http.Response> _send(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    try {
      return await _client
          .get(uri, headers: {'User-Agent': _userAgent, ...?headers})
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'Tempo esgotado ao consultar o INMET.',
        isConnectivity: true,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(
        'Sem conexão com o INMET.',
        isConnectivity: true,
      );
    }
  }

  static int _findEocd(Uint8List tail, int tailStart, int fileLength) {
    final view = ByteData.sublistView(tail);
    for (var i = tail.length - 22; i >= 0; i--) {
      if (tail[i] != 0x50 ||
          tail[i + 1] != 0x4b ||
          tail[i + 2] != 0x05 ||
          tail[i + 3] != 0x06) {
        continue;
      }
      final commentLen = view.getUint16(i + 20, Endian.little);
      if (tailStart + i + 22 + commentLen == fileLength) return i;
    }
    return -1;
  }

  static _ZipEntry _findStation(Uint8List central) {
    final view = ByteData.sublistView(central);
    var pos = 0;
    _ZipEntry? found;
    while (pos + 46 <= central.length) {
      if (view.getUint32(pos, Endian.little) != 0x02014b50) break;
      final method = view.getUint16(pos + 10, Endian.little);
      final flags = view.getUint16(pos + 8, Endian.little);
      final compressed = view.getUint32(pos + 20, Endian.little);
      final uncompressed = view.getUint32(pos + 24, Endian.little);
      final nameLen = view.getUint16(pos + 28, Endian.little);
      final extraLen = view.getUint16(pos + 30, Endian.little);
      final commentLen = view.getUint16(pos + 32, Endian.little);
      final offset = view.getUint32(pos + 42, Endian.little);
      final nameBytes = central.sublist(pos + 46, pos + 46 + nameLen);
      final name = (flags & 0x800) != 0
          ? utf8.decode(nameBytes, allowMalformed: true)
          : latin1.decode(nameBytes);
      final upper = name.toUpperCase();
      if (upper.contains(stationCode) && upper.endsWith('.CSV')) {
        if (compressed == 0xffffffff || offset == 0xffffffff) {
          throw const ApiException(
            'O arquivo do INMET está em um formato ZIP64.',
          );
        }
        found = _ZipEntry(
          method: method,
          compressedSize: compressed,
          uncompressedSize: uncompressed,
          offset: offset,
        );
      }
      pos += 46 + nameLen + extraLen + commentLen;
    }
    if (found == null) {
      throw const ApiException(
        'O arquivo do INMET não contém a estação $stationCode.',
      );
    }
    return found;
  }

  static int? _column(List<String> headers, bool Function(String) test) {
    for (var i = 0; i < headers.length; i++) {
      final name = headers[i].trim().toUpperCase();
      if (test(name)) return i;
    }
    return null;
  }

  static double? _cell(List<String> cells, int index) {
    if (index >= cells.length) return null;
    final raw = cells[index].trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    var text = raw.replaceAll(',', '.');
    if (text.startsWith('.')) text = '0$text';
    if (text.startsWith('-.')) text = text.replaceFirst('-.', '-0.');
    final value = double.tryParse(text);
    if (value == null || value >= 900 || value <= -100) return null;
    return value;
  }

  static DateTime? _parseDate(String raw) {
    final parts = raw.trim().split(RegExp(r'[/-]'));
    if (parts.length < 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static Uri _resolve(String href) {
    final uri = Uri.parse(href);
    if (uri.hasScheme) return uri;
    return Uri.parse('https://portal.inmet.gov.br').resolveUri(uri);
  }

  static int? _contentRangeTotal(http.Response response) {
    final header = response.headers['content-range'];
    if (header == null) return null;
    final slash = header.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(header.substring(slash + 1));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dmy(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

class InmetClimate {
  const InmetClimate({required this.series, required this.note});

  final List<IndicatorSeries> series;
  final String note;
}

class _Day {
  double? tempMax;
  double? humidMin;
  double _precip = 0;
  bool _sawPrecip = false;

  double? get precip => _sawPrecip ? _precip : null;

  void add({double? tempMax, double? precip, double? humidMin}) {
    if (tempMax != null) {
      this.tempMax = this.tempMax == null
          ? tempMax
          : math.max(this.tempMax!, tempMax);
    }
    if (humidMin != null) {
      this.humidMin = this.humidMin == null
          ? humidMin
          : math.min(this.humidMin!, humidMin);
    }
    if (precip != null) {
      _precip += precip;
      _sawPrecip = true;
    }
  }
}

class _ZipEntry {
  const _ZipEntry({
    required this.method,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.offset,
  });

  final int method;
  final int compressedSize;
  final int uncompressedSize;
  final int offset;
}

class _Range {
  const _Range(this.bytes, this.total);
  final Uint8List bytes;
  final int total;
}
