class VaultAccessException implements Exception {
  final String message;

  const VaultAccessException(this.message);

  @override
  String toString() => message;
}
