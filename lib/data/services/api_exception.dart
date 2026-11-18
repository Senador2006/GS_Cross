/// Erro de comunicação com uma fonte de dados externa.
class ApiException implements Exception {
  const ApiException(this.message, {this.isConnectivity = false});

  final String message;

  /// `true` quando o problema é falta de conexão (o app pode usar o cache).
  final bool isConnectivity;

  @override
  String toString() => 'ApiException: $message';
}
