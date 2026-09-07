import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/models/encrypted_data.dart';
import 'package:key_vault/services/native_crypto_service.dart';

void main() {
  const channel = MethodChannel('com.oluwakemimafe.keyvault/crypto');

  TestWidgetsFlutterBinding.ensureInitialized();

  final service = NativeCryptoService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('unlockSession calls native unlockSession', () async {
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    await service.unlockSession();

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'unlockSession');
    expect(receivedCall!.arguments, isNull);
  });

  test('renewSession calls native renewSession', () async {
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    await service.renewSession();

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'renewSession');
    expect(receivedCall!.arguments, isNull);
  });

  test('lockSession calls native lockSession', () async {
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    await service.lockSession();

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'lockSession');
    expect(receivedCall!.arguments, isNull);
  });

  test('encrypt calls native encrypt and parses result', () async {
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;

          return {
            'cipherText': [1, 2, 3],
            'nonce': [4, 5, 6],
            'mac': [7, 8, 9],
          };
        });

    final result = await service.encrypt('secret-value');

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'encrypt');

    expect(receivedCall!.arguments, {'plainText': 'secret-value'});

    expect(result.cipherText, [1, 2, 3]);
    expect(result.nonce, [4, 5, 6]);
    expect(result.mac, [7, 8, 9]);
  });

  test('decrypt calls native decrypt with encrypted data', () async {
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;

          return 'decrypted-value';
        });

    final encryptedData = EncryptedData(
      cipherText: [1, 2, 3],
      nonce: [4, 5, 6],
      mac: [7, 8, 9],
    );

    final result = await service.decrypt(encryptedData);

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'decrypt');

    expect(receivedCall!.arguments, {
      'cipherText': [1, 2, 3],
      'nonce': [4, 5, 6],
      'mac': [7, 8, 9],
    });

    expect(result, 'decrypted-value');
  });

  test('deleteKey calls native deleteKey', () async {
    MethodCall? receivedCall;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    await service.deleteKey();

    expect(receivedCall, isNotNull);
    expect(receivedCall!.method, 'deleteKey');
    expect(receivedCall!.arguments, isNull);
  });

  test('unlockSession throws AuthenticationRequiredException '
      'when native authentication is required', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'unlockSession') {
            throw PlatformException(
              code: 'AUTHENTICATION_REQUIRED',
              message: 'User authentication is required to unlock the vault.',
            );
          }

          return null;
        });

    expect(
      () => service.unlockSession(),
      throwsA(isA<AuthenticationRequiredException>()),
    );
  });

  test('encrypt throws AuthenticationRequiredException '
      'when native authentication is required', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'encrypt') {
            throw PlatformException(
              code: 'AUTHENTICATION_REQUIRED',
              message:
                  'User authentication is required to use '
                  'the vault encryption key.',
            );
          }

          return null;
        });

    expect(
      () => service.encrypt('TestPassword123!'),
      throwsA(isA<AuthenticationRequiredException>()),
    );
  });

  test('decrypt throws AuthenticationRequiredException '
      'when native authentication is required', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'decrypt') {
            throw PlatformException(
              code: 'AUTHENTICATION_REQUIRED',
              message:
                  'User authentication is required to use '
                  'the vault encryption key.',
            );
          }

          return null;
        });

    expect(
      () => service.decrypt(
        EncryptedData(cipherText: [1, 2, 3], nonce: [4, 5, 6], mac: [7, 8, 9]),
      ),
      throwsA(isA<AuthenticationRequiredException>()),
    );
  });
}
