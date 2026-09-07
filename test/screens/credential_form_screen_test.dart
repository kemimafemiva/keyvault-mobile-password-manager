import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_vault/models/authentication_result.dart';
import 'package:key_vault/models/credential.dart';
import 'package:key_vault/repositories/credential_repository.dart';
import 'package:key_vault/screens/credential_form_screen.dart';

import '../fakes/fake_authentication_service.dart';
import '../fakes/fake_credential_storage_service.dart';
import '../fakes/fake_native_crypto_service.dart';

void main() {
  late FakeAuthenticationService authenticationService;
  late FakeCredentialStorageService storageService;
  late FakeNativeCryptoService cryptoService;
  late CredentialRepository repository;

  setUp(() {
    authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    storageService = FakeCredentialStorageService();
    cryptoService = FakeNativeCryptoService();

    repository = CredentialRepository(
      cryptoService: cryptoService,
      storageService: storageService,
    );
  });

  Widget buildCredentialForm({
    Credential? credential,
    Future<bool> Function()? onReauthenticate,
    Future<bool> Function()? onSessionExpired,
  }) {
    return MaterialApp(
      home: CredentialFormScreen(
        repository: repository,
        onReauthenticate:
            onReauthenticate ??
            () async {
              final result = await authenticationService.authenticate();
              return result == AuthenticationResult.success;
            },
        onSessionExpired:
            onSessionExpired ??
            () async {
              final result = await authenticationService.authenticate();
              return result == AuthenticationResult.success;
            },
        credential: credential,
      ),
    );
  }

  Future<void> enterValidCredential(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Service'),
      'Example Service',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'user@example.com',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'TestPassword123!',
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      'https://example.com',
    );
  }

  testWidgets('service name must contain at least 2 characters', (
    tester,
  ) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Service'), 'A');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('at least 2 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('service name cannot exceed 100 characters', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Service'),
      'A' * 101,
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('no more than 100 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('username or email must contain at least 2 characters', (
    tester,
  ) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'A',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('at least 2 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('username or email cannot exceed 254 characters', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'A' * 255,
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('no more than 254 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('username containing @ is accepted', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'john@work',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cryptoService.encryptCallCount, 1);
  });

  testWidgets('password must contain at least 8 characters', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Test1!',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('at least 8 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('password cannot exceed 128 characters', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      '${'A' * 127}1!',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('no more than 128 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('password requires an uppercase letter', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123!',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text('Password must include:\n• an uppercase letter'),
      findsOneWidget,
    );

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('password requires a number', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'TestPassword!',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Password must include:\n• a number'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('password requires a special character', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'TestPassword123',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text('Password must include:\n• a special character'),
      findsOneWidget,
    );

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('whitespace does not count as a special character', (
    tester,
  ) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Password123 ',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text('Password must include:\n• a special character'),
      findsOneWidget,
    );

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('password reports multiple validation failures together', (
    tester,
  ) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text(
        'Password must include:\n'
        '• an uppercase letter\n'
        '• a number\n'
        '• a special character',
      ),
      findsOneWidget,
    );

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('website is optional', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      '',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cryptoService.encryptCallCount, 1);
  });

  testWidgets('website accepts http URL', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      'http://example.com',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cryptoService.encryptCallCount, 1);
  });

  testWidgets('website accepts https URL', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cryptoService.encryptCallCount, 1);
  });

  testWidgets('website rejects malformed URL', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      'example.com',
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.textContaining('a valid URL starting with http:// or https://'),
      findsOneWidget,
    );

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('website cannot exceed 2048 characters', (tester) async {
    await tester.pumpWidget(buildCredentialForm());

    await enterValidCredential(tester);

    final website = 'https://example.com/${'a' * 2030}';

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Website (optional)'),
      website,
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('no more than 2048 characters'), findsOneWidget);

    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('invalid form does not request reauthentication', (tester) async {
    var reauthenticationCallCount = 0;
    var sessionExpiredCallCount = 0;

    await tester.pumpWidget(
      buildCredentialForm(
        onReauthenticate: () async {
          reauthenticationCallCount++;
          return true;
        },
        onSessionExpired: () async {
          sessionExpiredCallCount++;
          return true;
        },
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(reauthenticationCallCount, 0);
    expect(sessionExpiredCallCount, 0);
    expect(cryptoService.encryptCallCount, 0);
  });

  testWidgets('valid add saves without unnecessary authentication', (
    tester,
  ) async {
    var reauthenticationCallCount = 0;
    var sessionExpiredCallCount = 0;

    await tester.pumpWidget(
      buildCredentialForm(
        onReauthenticate: () async {
          reauthenticationCallCount++;
          return true;
        },
        onSessionExpired: () async {
          sessionExpiredCallCount++;
          return true;
        },
      ),
    );

    await enterValidCredential(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(cryptoService.encryptCallCount, 1);
    expect(reauthenticationCallCount, 0);
    expect(sessionExpiredCallCount, 0);

    final credentials = await repository.getCredentials();

    expect(credentials.length, 1);
    expect(credentials.first.serviceName, 'Example Service');
    expect(credentials.first.username, 'user@example.com');
    expect(credentials.first.password, 'TestPassword123!');
    expect(credentials.first.website, 'https://example.com');
  });

  testWidgets('add recovers expired session and retries once', (tester) async {
    var reauthenticationCallCount = 0;
    var sessionExpiredCallCount = 0;

    cryptoService.authenticationRequiredEncryptCount = 1;

    await tester.pumpWidget(
      buildCredentialForm(
        onReauthenticate: () async {
          reauthenticationCallCount++;
          return true;
        },
        onSessionExpired: () async {
          sessionExpiredCallCount++;
          return true;
        },
      ),
    );

    await enterValidCredential(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(reauthenticationCallCount, 0);
    expect(sessionExpiredCallCount, 1);
    expect(cryptoService.encryptCallCount, 2);

    final credentials = await repository.getCredentials();

    expect(credentials.length, 1);
    expect(credentials.first.serviceName, 'Example Service');
  });

  testWidgets('add does not retry when expired session recovery fails', (
    tester,
  ) async {
    var reauthenticationCallCount = 0;
    var sessionExpiredCallCount = 0;

    cryptoService.authenticationRequiredEncryptCount = 1;

    await tester.pumpWidget(
      buildCredentialForm(
        onReauthenticate: () async {
          reauthenticationCallCount++;
          return true;
        },
        onSessionExpired: () async {
          sessionExpiredCallCount++;
          return false;
        },
      ),
    );

    await enterValidCredential(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(reauthenticationCallCount, 0);
    expect(sessionExpiredCallCount, 1);
    expect(cryptoService.encryptCallCount, 1);

    expect(
      find.text('Authentication is required to save this credential.'),
      findsOneWidget,
    );

    expect(storageService.storedValue, isNull);
  });

  testWidgets(
    'add stops after one retry when authentication is still required',
    (tester) async {
      var reauthenticationCallCount = 0;
      var sessionExpiredCallCount = 0;

      cryptoService.shouldRequireAuthentication = true;

      await tester.pumpWidget(
        buildCredentialForm(
          onReauthenticate: () async {
            reauthenticationCallCount++;
            return true;
          },
          onSessionExpired: () async {
            sessionExpiredCallCount++;
            return true;
          },
        ),
      );

      await enterValidCredential(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(reauthenticationCallCount, 0);
      expect(sessionExpiredCallCount, 1);
      expect(cryptoService.encryptCallCount, 2);

      expect(
        find.text('Authentication is required to access the vault.'),
        findsOneWidget,
      );

      expect(storageService.storedValue, isNull);
    },
  );

  testWidgets('edit requires reauthentication before saving', (tester) async {
    var reauthenticationCallCount = 0;
    var sessionExpiredCallCount = 0;

    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example Service',
      username: 'user@example.com',
      password: 'TestPassword123!',
      website: 'https://example.com',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    final encryptCallsBeforeEdit = cryptoService.encryptCallCount;

    await tester.pumpWidget(
      buildCredentialForm(
        credential: credential,
        onReauthenticate: () async {
          reauthenticationCallCount++;
          return true;
        },
        onSessionExpired: () async {
          sessionExpiredCallCount++;
          return true;
        },
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'updated@example.com',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(reauthenticationCallCount, 1);
    expect(sessionExpiredCallCount, 0);
    expect(cryptoService.encryptCallCount, encryptCallsBeforeEdit + 1);

    final credentials = await repository.getCredentials();

    expect(credentials.length, 1);
    expect(credentials.first.username, 'updated@example.com');
  });

  testWidgets('edit does not save when reauthentication fails', (tester) async {
    var reauthenticationCallCount = 0;
    var sessionExpiredCallCount = 0;

    final now = DateTime.now();

    final credential = Credential(
      id: '1',
      serviceName: 'Example Service',
      username: 'user@example.com',
      password: 'TestPassword123!',
      website: 'https://example.com',
      createdAt: now,
      updatedAt: now,
    );

    await repository.addCredential(credential);

    final encryptCallsBeforeEdit = cryptoService.encryptCallCount;

    await tester.pumpWidget(
      buildCredentialForm(
        credential: credential,
        onReauthenticate: () async {
          reauthenticationCallCount++;
          return false;
        },
        onSessionExpired: () async {
          sessionExpiredCallCount++;
          return true;
        },
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username or email'),
      'updated@example.com',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(reauthenticationCallCount, 1);
    expect(sessionExpiredCallCount, 0);
    expect(cryptoService.encryptCallCount, encryptCallsBeforeEdit);

    expect(
      find.text('Authentication is required to edit this credential.'),
      findsOneWidget,
    );

    final credentials = await repository.getCredentials();

    expect(credentials.length, 1);
    expect(credentials.first.username, 'user@example.com');
  });
}
