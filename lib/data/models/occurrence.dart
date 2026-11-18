import 'indicator.dart';

/// Categorias de ocorrência que o cidadão pode relatar. Cada uma está ligada
/// a um domínio, o que permite cruzar relatos com os indicadores.
enum OccurrenceCategory {
  waterLeak('Vazamento de água', TerritoryDomain.resources, 'water_loss'),
  powerOutage('Falta de energia', TerritoryDomain.resources, 'energy_outages'),
  flooding('Alagamento', TerritoryDomain.climate, 'precipitation'),
  heat('Calor extremo / mal-estar', TerritoryDomain.climate, 'temp_max'),
  irregularDumping(
    'Descarte irregular de lixo',
    TerritoryDomain.waste,
    'irregular_dumping',
  ),
  missedCollection(
    'Coleta não realizada',
    TerritoryDomain.waste,
    'waste_collected',
  ),
  healthQueue('Fila / demora na UBS', TerritoryDomain.services, 'wait_time'),
  urbanMaintenance(
    'Manutenção urbana',
    TerritoryDomain.services,
    'service_requests',
  );

  const OccurrenceCategory(this.label, this.domain, this.relatedIndicatorId);
  final String label;
  final TerritoryDomain domain;
  final String relatedIndicatorId;
}

enum OccurrenceSeverity {
  low('Baixa'),
  medium('Média'),
  high('Alta');

  const OccurrenceSeverity(this.label);
  final String label;
}

enum SyncStatus {
  pending('Aguardando envio'),
  synced('Enviado');

  const SyncStatus(this.label);
  final String label;
}

/// Ocorrência registrada por um cidadão.
///
/// Privacidade por design: não há nome, CPF, telefone ou endereço. O autor é
/// identificado apenas por um pseudônimo ([reporterHash]) e a localização,
/// quando consentida, é arredondada para uma grade de ~1 km.
class Occurrence {
  const Occurrence({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.neighborhood,
    required this.severity,
    required this.occurredOn,
    required this.createdAt,
    required this.reporterHash,
    required this.syncStatus,
    this.approxLatitude,
    this.approxLongitude,
    this.affectedPeople,
  });

  final String id;
  final OccurrenceCategory category;
  final String title;
  final String description;
  final String neighborhood;
  final OccurrenceSeverity severity;
  final DateTime occurredOn;
  final DateTime createdAt;
  final String reporterHash;
  final SyncStatus syncStatus;
  final double? approxLatitude;
  final double? approxLongitude;
  final int? affectedPeople;

  bool get hasLocation => approxLatitude != null && approxLongitude != null;

  Occurrence copyWith({SyncStatus? syncStatus}) => Occurrence(
    id: id,
    category: category,
    title: title,
    description: description,
    neighborhood: neighborhood,
    severity: severity,
    occurredOn: occurredOn,
    createdAt: createdAt,
    reporterHash: reporterHash,
    syncStatus: syncStatus ?? this.syncStatus,
    approxLatitude: approxLatitude,
    approxLongitude: approxLongitude,
    affectedPeople: affectedPeople,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'description': description,
    'neighborhood': neighborhood,
    'severity': severity.name,
    'occurredOn': occurredOn.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'reporterHash': reporterHash,
    'syncStatus': syncStatus.name,
    'approxLatitude': approxLatitude,
    'approxLongitude': approxLongitude,
    'affectedPeople': affectedPeople,
  };

  factory Occurrence.fromJson(Map<String, dynamic> json) => Occurrence(
    id: json['id'] as String,
    category: OccurrenceCategory.values.byName(json['category'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    neighborhood: json['neighborhood'] as String,
    severity: OccurrenceSeverity.values.byName(json['severity'] as String),
    occurredOn: DateTime.parse(json['occurredOn'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    reporterHash: json['reporterHash'] as String,
    syncStatus: SyncStatus.values.byName(json['syncStatus'] as String),
    approxLatitude: (json['approxLatitude'] as num?)?.toDouble(),
    approxLongitude: (json['approxLongitude'] as num?)?.toDouble(),
    affectedPeople: json['affectedPeople'] as int?,
  );
}
