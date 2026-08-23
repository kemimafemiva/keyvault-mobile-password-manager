import 'package:key_vault/models/authentication_result.dart';
import 'package:key_vault/services/authentication_service.dart';
import 'package:local_auth/local_auth.dart';

class FakeAuthenticationService extends AuthenticationService {
  FakeAuthenticationService({
    this.authenticationAvailable = true,
    this.biometricAvailable = true,
    this.authenticationResult = AuthenticationResult.success,
  });

  bool authenticationAvailable;
  bool biometricAvailable;
  AuthenticationResult authenticationResult;

  int authenticationCallCount = 0;

  @override
  Future<bool> isAuthenticationAvailable() async {
    return authenticationAvailable;
  }

  @override
  Future<bool> isBiometricAvailable() async {
    return biometricAvailable;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return biometricAvailable ? [BiometricType.face] : [];
  }

  @override
  Future<AuthenticationResult> authenticate() async {
    authenticationCallCount++;
    return authenticationResult;
  }
}
