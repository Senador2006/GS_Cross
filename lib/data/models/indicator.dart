import 'data_point.dart';

/// Domínios temáticos — cada um corresponde a um dashboard do app.
enum TerritoryDomain {
  resources('Recursos', 'Água e energia'),
  climate('Clima', 'Clima local'),
  waste('Resíduos', 'Coleta e descarte'),
  services('Serviços', 'Demanda por serviços públicos');

  const TerritoryDomain(this.label, this.subtitle);

  final String label;
  final String subtitle;

  static TerritoryDomain fromName(String name) =>
      TerritoryDomain.values.firstWhere((d) => d.name == name);
}

/// Em que direção o indicador piora. Usado nos limiares e nas tendências.
enum WorseDirection {
  /// Valores altos são ruins (ex.: perdas de água, tempo de espera).
  higher,

  /// Valores baixos são ruins (ex.: taxa de reciclagem, umidade do ar).
  lower,
}

/// Origem do dado — exibida na UI para transparência.
enum DataOrigin {
  publicApi('API pública (Open-Meteo)'),
  synthetic('Dados sintéticos simulados');

  const DataOrigin(this.label);
  final String label;
}

/// Metadados estáticos de um indicador territorial.
class IndicatorDefinition {
  const IndicatorDefinition({
    required this.id,
    required this.domain,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.description,
    required this.worseDirection,
    required this.defaultWarning,
    required this.defaultCritical,
    required this.minPlausible,
    required this.maxPlausible,
    required this.affectedPopulation,
    this.decimals = 1,
  });

  final String id;
  final TerritoryDomain domain;
  final String name;
  final String shortName;
  final String unit;
  final String description;
  final WorseDirection worseDirection;
  final double defaultWarning;
  final double defaultCritical;

  /// Faixa fisicamente plausível — usada para validar limiares no formulário.
  final double minPlausible;
  final double maxPlausible;

  /// Estimativa de pessoas afetadas quando o indicador está em alerta.
  /// Base do indicador de benefício social.
  final int affectedPopulation;
  final int decimals;
}

/// Série histórica de um indicador, como recebida da fonte.
class IndicatorSeries {
  const IndicatorSeries({
    required this.definition,
    required this.points,
    required this.origin,
  });

  final IndicatorDefinition definition;
  final List<DataPoint> points;
  final DataOrigin origin;

  String get id => definition.id;

  /// Último valor válido (não faltante).
  DataPoint? get lastValid {
    for (var i = points.length - 1; i >= 0; i--) {
      if (!points[i].isMissing) return points[i];
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': definition.id,
    'origin': origin.name,
    'points': points.map((p) => p.toJson()).toList(),
  };
}
