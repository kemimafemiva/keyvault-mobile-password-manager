import 'dart:convert';

import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/exceptions/vault_access_exception.dart';
import 'package:key_vault/services/native_crypto_service.dart';

import '../models/credential.dart';
import '../models/encrypted_data.dart';
import '../services/credential_storage_service.dart';

class CredentialRepository {
  final NativeCryptoService _cryptoService;
  final CredentialStorageService _storageService;

  CredentialRepository({
    required NativeCryptoService cryptoService,
    required CredentialStorageService storageService,
  }) : _cryptoService = cryptoService,
       _storageService = storageService;

  Future<List<Credential>> getCredentials() async {
    final storedVault = await _storageService.read();

    if (storedVault == null) {
      return [];
    }

    final encryptedJson = jsonDecode(storedVault) as Map<String, dynamic>;
    final encryptedData = EncryptedData.fromJson(encryptedJson);

    try {
      final decryptedVault = await _cryptoService.decrypt(encryptedData);
      final decodedCredentials = jsonDecode(decryptedVault) as List<dynamic>;

      return decodedCredentials
          .map((item) => Credential.fromJson(item as Map<String, dynamic>))
          .toList();
    } on AuthenticationRequiredException {
      rethrow;
    } catch (_) {
      throw const VaultAccessException(
        'The encrypted vault could not be decrypted.',
      );
    }
  }

  Future<void> addCredential(Credential credential) async {
    final credentials = await getCredentials();

    credentials.add(credential);

    await _saveCredentials(credentials);
  }

  Future<void> updateCredential(Credential credential) async {
    final credentials = await getCredentials();

    final index = credentials.indexWhere((item) => item.id == credential.id);

    if (index == -1) {
      throw StateError('Credential not found.');
    }

    credentials[index] = credential;

    await _saveCredentials(credentials);
  }

  Future<void> deleteCredential(String id) async {
    final credentials = await getCredentials();

    credentials.removeWhere((credential) => credential.id == id);

    await _saveCredentials(credentials);
  }

  Future<void> resetVault() async {
    await _storageService.delete();
    await _cryptoService.deleteKey();
  }

  Future<void> _saveCredentials(List<Credential> credentials) async {
    final serializedCredentials = jsonEncode(
      credentials.map((credential) => credential.toJson()).toList(),
    );

    final encryptedData = await _cryptoService.encrypt(serializedCredentials);

    final encryptedVault = jsonEncode(encryptedData.toJson());

    await _storageService.write(encryptedVault);
  }
}
