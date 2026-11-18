import 'package:material_ui/material_ui.dart' show ThemeMode;

/// Perfil de uso. Gestores registram decisões sobre alertas; cidadãos
/// acompanham indicadores e registram ocorrências.
enum UserRole {
  manager('Gestor(a) público(a)'),
  citizen('Cidadão / cidadã');

  const UserRole(this.label);
  final String label;
}

/// Consentimento explícito (LGPD, art. 8º): registrado com versão e data,
/// revogável a qualquer momento na tela de Privacidade.
class ConsentRecord {
  const ConsentRecord({
    required this.version,
    required this.acceptedAt,
    required this.dataProcessing,
    required this.approximateLocation,
  });

  static const currentVersion = 1;

  final int version;
  final DateTime acceptedAt;

  /// Obrigatório: tratamento de dados anonimizados para análise territorial.
  final bool dataProcessing;

  /// Opcional: anexar localização aproximada (~1 km) às ocorrências.
  final bool approximateLocation;

  bool get isValid => dataProcessing && version == currentVersion;

  Map<String, dynamic> toJson() => {
    'version': version,
    'acceptedAt': acceptedAt.toIso8601String(),
    'dataProcessing': dataProcessing,
    'approximateLocation': approximateLocation,
  };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) => ConsentRecord(
    version: json['version'] as int,
    acceptedAt: DateTime.parse(json['acceptedAt'] as String),
    dataProcessing: json['dataProcessing'] as bool,
    approximateLocation: json['approximateLocation'] as bool,
  );
}

/// Preferências de interface e acessibilidade.
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.highContrast = false,
    this.textScale = 1.0,
    this.role = UserRole.manager,
    this.simulateOffline = false,
    this.reduceMotion = false,
  });

  final ThemeMode themeMode;
  final bool highContrast;

  /// Multiplicador aplicado sobre a escala de fonte do sistema.
  final double textScale;
  final UserRole role;

  /// Ferramenta de demonstração: força falha de rede para exibir o modo
  /// offline (cache) e os estados de erro.
  final bool simulateOffline;
  final bool reduceMotion;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? highContrast,
    double? textScale,
    UserRole? role,
    bool? simulateOffline,
    bool? reduceMotion,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    textScale: textScale ?? this.textScale,
    role: role ?? this.role,
    simulateOffline: simulateOffline ?? this.simulateOffline,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'highContrast': highContrast,
    'textScale': textScale,
    'role': role.name,
    'simulateOffline': simulateOffline,
    'reduceMotion': reduceMotion,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    themeMode: ThemeMode.values.byName(json['themeMode'] as String),
    highContrast: json['highContrast'] as bool? ?? false,
    textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
    role: UserRole.values.byName(json['role'] as String? ?? 'manager'),
    simulateOffline: json['simulateOffline'] as bool? ?? false,
    reduceMotion: json['reduceMotion'] as bool? ?? false,
  );
}
