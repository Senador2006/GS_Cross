import 'package:flutter_test/flutter_test.dart';
import 'package:radar_territorial/core/constants/territory.dart';
import 'package:radar_territorial/core/utils/privacy.dart';
import 'package:radar_territorial/core/utils/validators.dart';
import 'package:radar_territorial/data/models/indicator.dart';

void main() {
  group('Validators.textLength', () {
    test('obrigatório, mínimo e máximo', () {
      expect(
        Validators.textLength('', field: 'X', min: 5, max: 10),
        contains('obrigatório'),
      );
      expect(
        Validators.textLength('abc', field: 'X', min: 5, max: 10),
        contains('pelo menos 5'),
      );
      expect(
        Validators.textLength('a' * 11, field: 'X', min: 5, max: 10),
        contains('no máximo 10'),
      );
      expect(
        Validators.textLength('abcdef', field: 'X', min: 5, max: 10),
        isNull,
      );
    });

    test('bloqueia dados pessoais', () {
      String? v(String t) =>
          Validators.textLength(t, field: 'X', min: 1, max: 200);
      expect(v('meu cpf é 123.456.789-09'), contains('CPF'));
      expect(v('fale com joao@email.com'), contains('e-mail'));
      expect(v('ligue (11) 98765-4321'), contains('telefone'));
      expect(v('Vazamento há 3 dias na rua'), isNull);
    });
  });

  test('data da ocorrência', () {
    final now = DateTime(2026, 11, 18, 10);
    expect(Validators.occurrenceDate(null, now), isNotNull);
    expect(
      Validators.occurrenceDate(DateTime(2026, 11, 19), now),
      contains('futuro'),
    );
    expect(
      Validators.occurrenceDate(DateTime(2026, 10, 1), now),
      contains('30 dias'),
    );
    expect(Validators.occurrenceDate(DateTime(2026, 11, 18), now), isNull);
  });

  test('inteiro opcional', () {
    expect(Validators.optionalInt('', field: 'N', min: 1, max: 10), isNull);
    expect(Validators.optionalInt('0', field: 'N', min: 1, max: 10), isNotNull);
    expect(Validators.optionalInt('5', field: 'N', min: 1, max: 10), isNull);
  });

  group('limiares', () {
    final water = IndicatorCatalog.byId('water_consumption');

    test('parseDecimal aceita vírgula e ponto', () {
      expect(Validators.parseDecimal('12,5'), 12.5);
      expect(Validators.parseDecimal('1.250,5'), 1250.5);
      expect(Validators.parseDecimal('12.5'), 12.5);
      expect(Validators.parseDecimal('abc'), isNull);
    });

    test('valor fora da faixa plausível', () {
      expect(Validators.thresholdValue('-1', water), contains('Fora da faixa'));
      expect(Validators.thresholdValue('x', water), contains('números'));
      expect(Validators.thresholdValue('44', water), isNull);
    });

    test('crítico deve ser pior que atenção', () {
      expect(
        Validators.thresholdPair(
          warning: 44,
          critical: 40,
          direction: WorseDirection.higher,
        ),
        contains('MAIOR'),
      );
      expect(
        Validators.thresholdPair(
          warning: 6,
          critical: 8,
          direction: WorseDirection.lower,
        ),
        contains('MENOR'),
      );
      expect(
        Validators.thresholdPair(
          warning: 44,
          critical: 48,
          direction: WorseDirection.higher,
        ),
        isNull,
      );
    });
  });

  test('justificativa de decisão', () {
    expect(Validators.decisionNote('ok'), isNotNull);
    expect(Validators.decisionNote('Equipe enviada ao local.'), isNull);
  });

  group('Privacy', () {
    test('pseudônimo é estável e não reversível trivialmente', () {
      final salt = Privacy.newSalt();
      expect(Privacy.pseudonym(salt), Privacy.pseudonym(salt));
      expect(Privacy.pseudonym(salt), hasLength(12));
      expect(Privacy.pseudonym(salt), isNot(contains(salt)));
    });

    test('coordenadas arredondadas para ~1 km', () {
      expect(Privacy.coarsen(Territory.latitude), -23.54);
      expect(Privacy.coarsen(Territory.longitude), -46.46);
    });
  });
}
