import 'package:flutter_test/flutter_test.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/exceptions/vault_access_exception.dart';
import 'package:key_vault/models/credential.dart';
import 'package:key_vault/repositories/credential_repository.dart';

import '../fakes/fake_credential_storage_service.dart';
import '../fakes/fake_native_crypto_service.dart';

void main() {
  late CredentialRepository repository;
  late FakeCredentialStorageService storageService;
  late FakeNativeCryptoService cryptoService;

  setUp(() {
    storageService = FakeCredentialStorageService();
    cryptoService = FakeNativeCryptoService();

    repository = CredentialRepository(
      cryptoService: cryptoService,
      storageService: storageService,
    );
  });

  test('adds and retrieves a credential', () async {
    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example Service',
      username: 'user@example.com',
      password: 'SecretPassword123!',
      website: 'https://example.com',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    final credentials = await repository.getCredentials();

    expect(credentials.length, 1);
    expect(credentials.first.id, credential.id);
    expect(credentials.first.serviceName, credential.serviceName);
    expect(credentials.first.username, credential.username);
    expect(credentials.first.password, credential.password);
    expect(credentials.first.website, credential.website);
  });

  test('stored vault does not contain plaintext credential data', () async {
    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Sensitive Service',
      username: 'secret@example.com',
      password: 'VerySecretPassword123!',
      website: 'https://sensitive.example.com',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    final storedVault = storageService.storedValue;

    expect(storedVault, isNotNull);

    expect(storedVault, isNot(contains('Sensitive Service')));

    expect(storedVault, isNot(contains('secret@example.com')));

    expect(storedVault, isNot(contains('VerySecretPassword123!')));

    expect(storedVault, isNot(contains('sensitive.example.com')));
  });

  test('updates an existing credential', () async {
    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example',
      username: 'user@example.com',
      password: 'OldPassword',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    final updatedCredential = credential.copyWith(
      password: 'NewPassword',
      updatedAt: DateTime.now(),
    );

    await repository.updateCredential(updatedCredential);

    final credentials = await repository.getCredentials();

    expect(credentials.length, 1);
    expect(credentials.first.password, 'NewPassword');
  });

  test('deletes an existing credential', () async {
    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example',
      username: 'user@example.com',
      password: 'SecretPassword',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    await repository.deleteCredential(credential.id);

    final credentials = await repository.getCredentials();

    expect(credentials, isEmpty);
  });

  test('returns an empty list when no vault exists', () async {
    final credentials = await repository.getCredentials();

    expect(credentials, isEmpty);
  });

  test('fails securely when encrypted vault cannot be decrypted', () async {
    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example',
      username: 'user@example.com',
      password: 'SecretPassword',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    final originalVault = storageService.storedValue;

    cryptoService.shouldFailDecryption = true;

    expect(
      () => repository.getCredentials(),
      throwsA(isA<VaultAccessException>()),
    );

    // Existing encrypted data must remain untouched.
    expect(storageService.storedValue, originalVault);
  });

  test('reset deletes the encrypted vault and encryption key', () async {
    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example',
      username: 'user@example.com',
      password: 'SecretPassword',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    expect(storageService.storedValue, isNotNull);

    await repository.resetVault();

    expect(storageService.storedValue, isNull);
    expect(cryptoService.deleteKeyCallCount, 1);

    final credentials = await repository.getCredentials();

    expect(credentials, isEmpty);
  });

  test(
    'propagates authentication required without treating vault as corrupted',
    () async {
      final now = DateTime.now();

      final credential = Credential(
        id: '1',
        serviceName: 'Example',
        username: 'user@example.com',
        password: 'SecretPassword',
        createdAt: now,
        updatedAt: now,
      );

      await repository.addCredential(credential);

      final originalVault = storageService.storedValue;

      cryptoService.shouldRequireAuthentication = true;

      expect(
        () => repository.getCredentials(),
        throwsA(isA<AuthenticationRequiredException>()),
      );

      // Authentication failure must not modify or delete the vault.
      expect(storageService.storedValue, originalVault);
    },
  );
}
