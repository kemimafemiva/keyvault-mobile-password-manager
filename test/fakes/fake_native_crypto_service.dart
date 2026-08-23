import 'dart:convert';

import 'package:key_vault/models/encrypted_data.dart';
import 'package:key_vault/services/native_crypto_service.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';

class FakeNativeCryptoService extends NativeCryptoService {
  bool shouldFailDecryption = false;
  int deleteKeyCallCount = 0;
  bool shouldRequireAuthentication = false;

  @override
  Future<EncryptedData> encrypt(String plainText) async {
    final encoded = utf8.encode(plainText);

    return EncryptedData(
      cipherText: encoded.map((byte) => byte ^ 0xFF).toList(),
      nonce: List<int>.filled(12, 1),
      mac: List<int>.filled(16, 2),
    );
  }

  @override
  Future<String> decrypt(EncryptedData encryptedData) async {
    if (shouldRequireAuthentication) {
      throw AuthenticationRequiredException();
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
  }
}
