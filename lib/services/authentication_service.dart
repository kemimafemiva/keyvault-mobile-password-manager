import 'package:key_vault/models/authentication_result.dart';
import 'package:local_auth/local_auth.dart';

class AuthenticationService {
  final LocalAuthentication _localAuthentication;

  AuthenticationService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    return await _localAuthentication.canCheckBiometrics;
  }

  Future<bool> isAuthenticationAvailable() async {
    return await _localAuthentication.isDeviceSupported();
  }

  Future<List<BiometricType>> getAvailableBiometrics() {
    return _localAuthentication.getAvailableBiometrics();
  }

  Future<AuthenticationResult> authenticate() async {
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Authenticate to unlock KeyVault',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      return authenticated
          ? AuthenticationResult.success
          : AuthenticationResult.failed;
    } on LocalAuthException catch (exception) {
      switch (exception.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          return AuthenticationResult.unavailable;

        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return AuthenticationResult.notEnrolled;

        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return AuthenticationResult.lockedOut;

        default:
          return AuthenticationResult.failed;
      }
    } catch (exception) {
      return AuthenticationResult.failed;
    }
  }
}
