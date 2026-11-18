/// Um ponto de uma série temporal diária.
///
/// [value] pode ser `null` quando a fonte não enviou a medição daquele dia
/// (dado faltante). O motor de análise trata esses buracos explicitamente e
/// eles reduzem o nível de confiança das previsões.
class DataPoint {
  const DataPoint({required this.date, required this.value});

  final DateTime date;
  final double? value;

  bool get isMissing => value == null;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'value': value,
  };

  factory DataPoint.fromJson(Map<String, dynamic> json) => DataPoint(
    date: DateTime.parse(json['date'] as String),
    value: (json['value'] as num?)?.toDouble(),
  );
}
