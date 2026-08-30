import 'package:flutter/services.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';

import '../models/encrypted_data.dart';

class NativeCryptoService {
  static const MethodChannel _channel = MethodChannel(
    'com.oluwakemimafe.keyvault/crypto',
  );

  Future<void> unlockSession() async {
    try {
      await _channel.invokeMethod<void>('unlockSession');
    } on PlatformException catch (exception) {
      if (exception.code == 'AUTHENTICATION_REQUIRED') {
        throw const AuthenticationRequiredException();
      }

      rethrow;
    }
  }

  Future<void> lockSession() async {
    await _channel.invokeMethod<void>('lockSession');
  }

  Future<EncryptedData> encrypt(String plainText) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'encrypt',
        {'plainText': plainText},
      );

      if (result == null) {
        throw StateError('Native encryption returned no result.');
      }

      return EncryptedData(
        cipherText: List<int>.from(result['cipherText'] as List),
        nonce: List<int>.from(result['nonce'] as List),
        mac: List<int>.from(result['mac'] as List),
      );
    } on PlatformException catch (exception) {
      if (exception.code == 'AUTHENTICATION_REQUIRED') {
        throw const AuthenticationRequiredException();
      }

      rethrow;
    }
  }

  Future<String> decrypt(EncryptedData encryptedData) async {
    try {
      final result = await _channel.invokeMethod<String>('decrypt', {
        'cipherText': encryptedData.cipherText,
        'nonce': encryptedData.nonce,
        'mac': encryptedData.mac,
      });

      if (result == null) {
        throw StateError('Native decryption returned no result.');
      }

      return result;
    } on PlatformException catch (exception) {
      if (exception.code == 'AUTHENTICATION_REQUIRED') {
        throw const AuthenticationRequiredException();
      }

      rethrow;
    }
  }

  Future<void> deleteKey() {
    return _channel.invokeMethod<void>('deleteKey');
  }

  Future<bool> isSimulator() async {
    final result = await _channel.invokeMethod<bool>('isSimulator');

    return result ?? false;
  }
}
