import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Utilitários de anonimização (privacidade por design).
class Privacy {
  Privacy._();

  /// Gera um sal aleatório por instalação — nunca sai do dispositivo.
  static String newSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Pseudônimo estável do autor: SHA-256(sal da instalação), truncado.
  /// Permite agrupar relatos do mesmo dispositivo sem identificar a pessoa.
  static String pseudonym(String salt) {
    final digest = sha256.convert(utf8.encode('radar-territorial:$salt'));
    return digest.toString().substring(0, 12);
  }

  /// Arredonda coordenadas para uma grade de ~1,1 km (2 casas decimais),
  /// reduzindo o risco de reidentificação pelo endereço.
  static double coarsen(double coordinate) =>
      (coordinate * 100).roundToDouble() / 100;
}
