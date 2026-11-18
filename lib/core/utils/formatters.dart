import 'package:intl/intl.dart';

/// Formatação centralizada no padrão brasileiro.
class Fmt {
  Fmt._();

  static final _day = DateFormat('dd/MM', 'pt_BR');
  static final _dayYear = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dateTime = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');
  static final _weekday = DateFormat('EEE, dd/MM', 'pt_BR');

  static String day(DateTime d) => _day.format(d);
  static String date(DateTime d) => _dayYear.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String weekday(DateTime d) => _weekday.format(d);

  static String number(num value, {int decimals = 1}) =>
      NumberFormat.decimalPatternDigits(
        locale: 'pt_BR',
        decimalDigits: decimals,
      ).format(value);

  static String compact(num value) =>
      NumberFormat.compact(locale: 'pt_BR').format(value);

  static String percent(double ratio, {int decimals = 0}) =>
      '${number(ratio * 100, decimals: decimals)}%';

  static String signedPercent(double ratio) =>
      '${ratio >= 0 ? '+' : '−'}${number(ratio.abs() * 100, decimals: 1)}%';

  static String value(double? v, int decimals, String unit) =>
      v == null ? 'sem dado' : '${number(v, decimals: decimals)} $unit';

  static String duration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 48) return '${number(d.inMinutes / 60, decimals: 1)} h';
    return '${d.inDays} dias';
  }
}
