import 'dart:convert';

import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/models/encrypted_data.dart';
import 'package:key_vault/services/native_crypto_service.dart';

class FakeNativeCryptoService extends NativeCryptoService {
  bool shouldFailDecryption = false;
  bool shouldRequireAuthentication = false;
  bool shouldFailUnlock = false;

  int authenticationRequiredEncryptCount = 0;
  int unlockSessionCallCount = 0;
  int renewSessionCallCount = 0;
  int lockSessionCallCount = 0;
  int encryptCallCount = 0;
  int decryptCallCount = 0;
  int deleteKeyCallCount = 0;

  bool sessionUnlocked = false;

  @override
  Future<void> unlockSession() async {
    unlockSessionCallCount++;

    if (shouldFailUnlock) {
      throw const AuthenticationRequiredException();
    }

    sessionUnlocked = true;
  }

  @override
  Future<void> renewSession() async {
    renewSessionCallCount++;
  }

  @override
  Future<void> lockSession() async {
    lockSessionCallCount++;
    sessionUnlocked = false;
  }

  @override
  Future<EncryptedData> encrypt(String plainText) async {
    encryptCallCount++;

    if (shouldRequireAuthentication) {
      throw const AuthenticationRequiredException();
    }

    if (authenticationRequiredEncryptCount > 0) {
      authenticationRequiredEncryptCount--;
      throw const AuthenticationRequiredException();
    }

    final encoded = utf8.encode(plainText);

    return EncryptedData(
      cipherText: encoded.map((byte) => byte ^ 0xFF).toList(),
      nonce: List<int>.filled(12, 1),
      mac: List<int>.filled(16, 2),
    );
  }

  @override
  Future<String> decrypt(EncryptedData encryptedData) async {
    decryptCallCount++;

    if (shouldRequireAuthentication) {
      throw const AuthenticationRequiredException();
    }

    if (shouldFailDecryption) {
      throw StateError('Native key unavailable.');
    }

    final decoded =
        encryptedData.cipherText.map((byte) => byte ^ 0xFF).toList();

    return utf8.decode(decoded);
  }

  @override
  Future<void> deleteKey() async {
    deleteKeyCallCount++;
    sessionUnlocked = false;
  }
}
