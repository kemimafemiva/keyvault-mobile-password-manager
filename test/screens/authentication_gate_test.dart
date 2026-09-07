import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_vault/models/authentication_result.dart';
import 'package:key_vault/screens/authentication_gate.dart';

import '../fakes/fake_authentication_service.dart';
import '../fakes/fake_native_crypto_service.dart';

Future<void> tapUnlock(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Unlock'));
  await tester.pumpAndSettle();
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late FakeAuthenticationService authenticationService;
  late FakeNativeCryptoService cryptoService;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();

    authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    cryptoService = FakeNativeCryptoService();
  });

  Widget buildAuthenticationGate({
    Widget Function(
      VoidCallback onLock,
      Future<bool> Function() onReauthenticate,
      Future<bool> Function() onSessionExpired,
    )?
    unlockedBuilder,
  }) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: AuthenticationGate(
        authenticationService: authenticationService,
        cryptoService: cryptoService,
        navigatorKey: navigatorKey,
        unlockedBuilder:
            unlockedBuilder ??
            (_, _, _) => const Scaffold(body: Text('Vault content')),
      ),
    );
  }

  testWidgets('shows unlocked content after crypto session unlock succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthenticationGate());

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(find.text('KeyVault is locked'), findsNothing);

    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.sessionUnlocked, isTrue);
  });

  testWidgets('remains locked when crypto session unlock fails', (
    tester,
  ) async {
    cryptoService.shouldFailUnlock = true;

    await tester.pumpWidget(buildAuthenticationGate());

    await tapUnlock(tester);

    expect(find.text('KeyVault is locked'), findsOneWidget);
    expect(find.text('Vault content'), findsNothing);

    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.sessionUnlocked, isFalse);
  });

  testWidgets('locks the vault and crypto session when app is backgrounded', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthenticationGate());

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.sessionUnlocked, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpAndSettle();

    expect(find.text('Vault content'), findsNothing);
    expect(find.text('KeyVault is locked'), findsOneWidget);

    expect(cryptoService.lockSessionCallCount, 1);
    expect(cryptoService.sessionUnlocked, isFalse);

    // Returning to the foreground must not
    // automatically unlock the vault.
    expect(cryptoService.unlockSessionCallCount, 1);
  });

  testWidgets('requires a new crypto session unlock after backgrounding', (
    tester,
  ) async {
    await tester.pumpWidget(buildAuthenticationGate());

    await tapUnlock(tester);

    expect(cryptoService.unlockSessionCallCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpAndSettle();

    expect(cryptoService.sessionUnlocked, isFalse);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(cryptoService.unlockSessionCallCount, 2);
    expect(cryptoService.sessionUnlocked, isTrue);
    expect(find.text('Vault content'), findsOneWidget);
  });

  testWidgets('obscures protected content when app becomes inactive', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildAuthenticationGate(
        unlockedBuilder:
            (_, _, _) => const Scaffold(body: Text('Sensitive vault content')),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Sensitive vault content'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    await tester.pump();

    expect(find.byKey(const Key('privacy-overlay')), findsOneWidget);

    // Inactive only obscures the UI.
    // It does not invalidate the session.
    expect(cryptoService.lockSessionCallCount, 0);
    expect(cryptoService.sessionUnlocked, isTrue);
  });

  testWidgets('manual lock invalidates access and locks crypto session', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildAuthenticationGate(
        unlockedBuilder: (onLock, onReauthenticate, onSessionExpired) {
          return Scaffold(
            body: Column(
              children: [
                const Text('Vault content'),
                ElevatedButton(onPressed: onLock, child: const Text('Lock')),
              ],
            ),
          );
        },
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(cryptoService.sessionUnlocked, isTrue);

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();

    expect(find.text('Vault content'), findsNothing);
    expect(find.text('KeyVault is locked'), findsOneWidget);

    expect(cryptoService.lockSessionCallCount, 1);
    expect(cryptoService.sessionUnlocked, isFalse);
  });

  testWidgets('reauthentication renews the existing crypto session', (
    tester,
  ) async {
    Future<bool> Function()? reauthenticate;

    await tester.pumpWidget(
      buildAuthenticationGate(
        unlockedBuilder: (onLock, onReauthenticate, onSessionExpired) {
          reauthenticate = onReauthenticate;

          return const Scaffold(body: Text('Vault content'));
        },
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.renewSessionCallCount, 0);
    expect(cryptoService.sessionUnlocked, isTrue);
    expect(reauthenticate, isNotNull);

    // Initial unlock may itself use AuthenticationService
    // depending on the platform used by the widget test.
    final authenticationCallsBeforeReauthentication =
        authenticationService.authenticationCallCount;

    final result = await reauthenticate!();

    await tester.pump();

    expect(result, isTrue);

    // Deliberate reauthentication should make exactly
    // one additional authentication request.
    expect(
      authenticationService.authenticationCallCount,
      authenticationCallsBeforeReauthentication + 1,
    );

    // Successful reauthentication renews the existing
    // crypto session without unlocking or replacing it.
    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.renewSessionCallCount, 1);
    expect(cryptoService.lockSessionCallCount, 0);
    expect(cryptoService.sessionUnlocked, isTrue);

    expect(find.text('Vault content'), findsOneWidget);
    expect(find.text('KeyVault is locked'), findsNothing);
  });

  testWidgets('failed reauthentication preserves unlocked crypto session', (
    tester,
  ) async {
    Future<bool> Function()? reauthenticate;

    await tester.pumpWidget(
      buildAuthenticationGate(
        unlockedBuilder: (onLock, onReauthenticate, onSessionExpired) {
          reauthenticate = onReauthenticate;

          return const Scaffold(body: Text('Vault content'));
        },
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.sessionUnlocked, isTrue);
    expect(reauthenticate, isNotNull);

    // Record the existing authentication count so this
    // test is independent of initial unlock behaviour.
    final authenticationCallsBeforeReauthentication =
        authenticationService.authenticationCallCount;

    authenticationService.authenticationResult = AuthenticationResult.failed;

    final result = await reauthenticate!();

    await tester.pump();

    expect(result, isFalse);

    // A failed deliberate reauthentication still represents
    // exactly one authentication attempt.
    expect(
      authenticationService.authenticationCallCount,
      authenticationCallsBeforeReauthentication + 1,
    );

    // Failed deliberate reauthentication must not renew
    // or destroy the already unlocked crypto session.
    expect(cryptoService.unlockSessionCallCount, 1);
    expect(cryptoService.renewSessionCallCount, 0);
    expect(cryptoService.lockSessionCallCount, 0);
    expect(cryptoService.sessionUnlocked, isTrue);

    expect(find.text('Vault content'), findsOneWidget);
    expect(find.text('KeyVault is locked'), findsNothing);
  });

  testWidgets('expired session recovery uses the platform-specific flow', (
    tester,
  ) async {
    Future<bool> Function()? recoverExpiredSession;

    await tester.pumpWidget(
      buildAuthenticationGate(
        unlockedBuilder: (onLock, onReauthenticate, onSessionExpired) {
          recoverExpiredSession = onSessionExpired;

          return const Scaffold(body: Text('Vault content'));
        },
      ),
    );

    await tapUnlock(tester);

    expect(recoverExpiredSession, isNotNull);

    final authenticationCallsBeforeRecovery =
        authenticationService.authenticationCallCount;
    final unlockCallsBeforeRecovery = cryptoService.unlockSessionCallCount;

    final result = await recoverExpiredSession!();

    await tester.pump();

    expect(result, isTrue);

    if (Platform.isIOS) {
      // iOS recovers the expired session through Keychain
      // access without a separate local authentication call.
      expect(
        authenticationService.authenticationCallCount,
        authenticationCallsBeforeRecovery,
      );
      expect(
        cryptoService.unlockSessionCallCount,
        unlockCallsBeforeRecovery + 1,
      );
    } else {
      // Android refreshes the Keystore authorization through
      // authentication without another crypto session unlock.
      expect(
        authenticationService.authenticationCallCount,
        authenticationCallsBeforeRecovery + 1,
      );
      expect(cryptoService.unlockSessionCallCount, unlockCallsBeforeRecovery);
    }

    expect(cryptoService.renewSessionCallCount, 0);
  });

  testWidgets('failed expired session recovery returns false', (tester) async {
    Future<bool> Function()? recoverExpiredSession;

    await tester.pumpWidget(
      buildAuthenticationGate(
        unlockedBuilder: (onLock, onReauthenticate, onSessionExpired) {
          recoverExpiredSession = onSessionExpired;

          return const Scaffold(body: Text('Vault content'));
        },
      ),
    );

    await tapUnlock(tester);

    expect(recoverExpiredSession, isNotNull);

    if (Platform.isIOS) {
      cryptoService.shouldFailUnlock = true;
    } else {
      authenticationService.authenticationResult = AuthenticationResult.failed;
    }

    final authenticationCallsBeforeRecovery =
        authenticationService.authenticationCallCount;
    final unlockCallsBeforeRecovery = cryptoService.unlockSessionCallCount;

    final result = await recoverExpiredSession!();

    await tester.pump();

    expect(result, isFalse);

    if (Platform.isIOS) {
      expect(
        authenticationService.authenticationCallCount,
        authenticationCallsBeforeRecovery,
      );
      expect(
        cryptoService.unlockSessionCallCount,
        unlockCallsBeforeRecovery + 1,
      );
    } else {
      expect(
        authenticationService.authenticationCallCount,
        authenticationCallsBeforeRecovery + 1,
      );
      expect(cryptoService.unlockSessionCallCount, unlockCallsBeforeRecovery);
    }

    expect(cryptoService.renewSessionCallCount, 0);
  });
}
