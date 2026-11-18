import '../../core/constants/territory.dart';
import 'data_point.dart';
import 'indicator.dart';

/// Conjunto de séries do território em um momento de coleta.
class TerritorySnapshot {
  const TerritorySnapshot({
    required this.series,
    required this.fetchedAt,
    this.fromCache = false,
    this.warnings = const [],
    this.notes = const [],
    this.population = Territory.population,
  });

  final List<IndicatorSeries> series;
  final DateTime fetchedAt;

  /// `true` quando a rede falhou e os dados vieram do armazenamento local.
  final bool fromCache;

  /// Avisos de qualidade da coleta (ex.: fonte pública indisponível).
  final List<String> warnings;

  /// Origem dos dados públicos que responderam (INMET, IBGE).
  final List<String> notes;

  /// População do distrito. Vem do IBGE; [Territory.population] é o fallback.
  final int population;

  bool get isEmpty => series.isEmpty;

  IndicatorSeries? byId(String id) {
    for (final s in series) {
      if (s.id == id) return s;
    }
    return null;
  }

  TerritorySnapshot asCached() => TerritorySnapshot(
    series: series,
    fetchedAt: fetchedAt,
    fromCache: true,
    warnings: warnings,
    notes: notes,
    population: population,
  );

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'warnings': warnings,
    'notes': notes,
    'population': population,
    'series': series.map((s) => s.toJson()).toList(),
  };

  factory TerritorySnapshot.fromJson(Map<String, dynamic> json) {
    final series = <IndicatorSeries>[];
    for (final raw in (json['series'] as List).cast<Map<String, dynamic>>()) {
      final id = raw['id'] as String;
      // Ignora indicadores que deixaram de existir no catálogo.
      if (!IndicatorCatalog.all.any((d) => d.id == id)) continue;
      series.add(
        IndicatorSeries(
          definition: IndicatorCatalog.byId(id),
          origin: DataOrigin.values.byName(raw['origin'] as String),
          points: (raw['points'] as List)
              .cast<Map<String, dynamic>>()
              .map(DataPoint.fromJson)
              .toList(),
        ),
      );
    }
    return TerritorySnapshot(
      series: series,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      warnings: (json['warnings'] as List? ?? []).cast<String>(),
      notes: (json['notes'] as List? ?? []).cast<String>(),
      population: (json['population'] as num?)?.toInt() ?? Territory.population,
    );
  }
}
