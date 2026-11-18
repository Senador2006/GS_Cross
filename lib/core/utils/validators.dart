import '../../data/models/indicator.dart';

/// Validações de formulário com mensagens claras em português.
///
/// Cada função devolve `null` quando o valor é válido, ou a mensagem de erro
/// a ser exibida abaixo do campo (padrão de `FormField.validator`).
class Validators {
  Validators._();

  static final _cpf = RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final _phone = RegExp(r'(\(?\d{2}\)?\s?)?9?\d{4}[-\s]?\d{4}\b');

  /// Detecta dados pessoais óbvios digitados em campos de texto livre.
  static String? personalDataFound(String text) {
    if (_cpf.hasMatch(text)) return 'CPF';
    if (_email.hasMatch(text)) return 'e-mail';
    if (_phone.hasMatch(text)) return 'telefone';
    return null;
  }

  static String? required(Object? value, {String field = 'Este campo'}) {
    if (value == null) return '$field é obrigatório.';
    if (value is String && value.trim().isEmpty) {
      return '$field é obrigatório.';
    }
    return null;
  }

  static String? textLength(
    String? value, {
    required String field,
    required int min,
    required int max,
    bool checkPersonalData = true,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field é obrigatório.';
    if (text.length < min) {
      return '$field deve ter pelo menos $min caracteres '
          '(atual: ${text.length}).';
    }
    if (text.length > max) {
      return '$field deve ter no máximo $max caracteres '
          '(atual: ${text.length}).';
    }
    if (checkPersonalData) {
      final found = personalDataFound(text);
      if (found != null) {
        return 'Remova o $found: não inclua dados pessoais no relato.';
      }
    }
    return null;
  }

  /// Número inteiro opcional dentro de uma faixa.
  static String? optionalInt(
    String? value, {
    required String field,
    required int min,
    required int max,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final n = int.tryParse(text);
    if (n == null) return '$field deve ser um número inteiro.';
    if (n < min || n > max) return '$field deve estar entre $min e $max.';
    return null;
  }

  static String? occurrenceDate(DateTime? date, DateTime now) {
    if (date == null) return 'Informe a data da ocorrência.';
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d.isAfter(today)) return 'A data não pode estar no futuro.';
    if (today.difference(d).inDays > 30) {
      return 'Registre apenas ocorrências dos últimos 30 dias.';
    }
    return null;
  }

  /// Converte texto em número aceitando vírgula decimal.
  /// Com vírgula, o ponto é tratado como separador de milhar ("1.250,5");
  /// sem vírgula, o ponto é o separador decimal ("12.5").
  static double? parseDecimal(String? value) {
    var text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(text);
  }

  static String? thresholdValue(String? value, IndicatorDefinition def) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe um valor.';
    final n = parseDecimal(text);
    if (n == null) return 'Use apenas números (ex.: 12,5).';
    if (n < def.minPlausible || n > def.maxPlausible) {
      return 'Fora da faixa plausível (${_fmt(def.minPlausible)} a '
          '${_fmt(def.maxPlausible)} ${def.unit}).';
    }
    return null;
  }

  /// Regra cruzada: o limiar crítico precisa ser "pior" que o de atenção.
  static String? thresholdPair({
    required double? warning,
    required double? critical,
    required WorseDirection direction,
  }) {
    if (warning == null || critical == null) return null;
    if (direction == WorseDirection.higher && critical <= warning) {
      return 'O limiar crítico deve ser MAIOR que o de atenção.';
    }
    if (direction == WorseDirection.lower && critical >= warning) {
      return 'O limiar crítico deve ser MENOR que o de atenção.';
    }
    return null;
  }

  static String? decisionNote(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 10) {
      return 'Justifique a decisão com pelo menos 10 caracteres.';
    }
    if (text.length > 300) return 'Máximo de 300 caracteres.';
    final found = personalDataFound(text);
    if (found != null) return 'Remova o $found da justificativa.';
    return null;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
