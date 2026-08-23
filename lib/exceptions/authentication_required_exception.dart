class AuthenticationRequiredException implements Exception {
  const AuthenticationRequiredException();

  @override
  String toString() =>
      'User authentication is required to access the vault key.';
}
