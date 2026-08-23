import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:key_vault/models/authentication_result.dart';

import 'package:key_vault/screens/authentication_gate.dart';

import '../fakes/fake_authentication_service.dart';

Future<void> tapUnlock(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Unlock'));
  await tester.pumpAndSettle();
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
  });

  testWidgets('shows unlocked content after successful authentication', (
    tester,
  ) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(find.text('KeyVault is locked'), findsNothing);
  });

  testWidgets('remains locked after failed authentication', (tester) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.failed,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('KeyVault is locked'), findsOneWidget);

    expect(
      find.text('Authentication failed or was cancelled.'),
      findsOneWidget,
    );

    expect(find.text('Vault content'), findsNothing);
  });

  testWidgets('remains locked when biometrics are unavailable', (tester) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.unavailable,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('KeyVault is locked'), findsOneWidget);

    expect(
      find.text('Biometric authentication is not available on this device.'),
      findsOneWidget,
    );

    expect(find.text('Vault content'), findsNothing);
  });

  testWidgets('locks the vault when the app is backgrounded', (tester) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(authenticationService.authenticationCallCount, 1);

    // A fresh authentication attempt must not automatically succeed.
    authenticationService.authenticationResult = AuthenticationResult.failed;

    // Background the application.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    // Return it to the foreground so the test binding can process frames.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpAndSettle();

    // The previous authenticated session must no longer grant access.
    expect(find.text('Vault content'), findsNothing);
    expect(find.text('KeyVault is locked'), findsOneWidget);

    // Returning to KeyVault requires an explicit fresh authentication.
    expect(authenticationService.authenticationCallCount, 1);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(authenticationService.authenticationCallCount, 2);

    expect(
      find.text('Authentication failed or was cancelled.'),
      findsOneWidget,
    );
  });

  testWidgets('remains locked when no biometrics are enrolled', (tester) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.notEnrolled,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('KeyVault is locked'), findsOneWidget);
    expect(find.text('Vault content'), findsNothing);

    expect(
      find.text('No biometrics are enrolled on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('remains locked when biometric authentication is locked out', (
    tester,
  ) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.lockedOut,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('KeyVault is locked'), findsOneWidget);
    expect(find.text('Vault content'), findsNothing);

    expect(
      find.text(
        'Biometric authentication is temporarily unavailable. '
        'Try again later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('obscures protected content when the app becomes inactive', (
    tester,
  ) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder:
              (_, _) => const Scaffold(body: Text('Sensitive vault content')),
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Sensitive vault content'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    await tester.pump();

    expect(find.byKey(const Key('privacy-overlay')), findsOneWidget);

    // Inactive alone does not invalidate authentication.
    expect(authenticationService.authenticationCallCount, 1);
  });

  testWidgets('manually locking invalidates access to protected content', (
    tester,
  ) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder: (onLock, onReauthenticate) {
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
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();

    expect(find.text('Vault content'), findsNothing);
    expect(find.text('KeyVault is locked'), findsOneWidget);
  });

  testWidgets('reauthenticates without locking the vault', (tester) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    Future<bool> Function()? reauthenticate;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder: (onLock, onReauthenticate) {
            reauthenticate = onReauthenticate;

            return const Scaffold(body: Text('Vault content'));
          },
        ),
      ),
    );

    await tapUnlock(tester);

    expect(find.text('Vault content'), findsOneWidget);
    expect(authenticationService.authenticationCallCount, 1);
    expect(reauthenticate, isNotNull);

    final result = await reauthenticate!();

    await tester.pump();

    expect(result, isTrue);
    expect(authenticationService.authenticationCallCount, 2);

    // Reauthentication must not lock the existing session.
    expect(find.text('Vault content'), findsOneWidget);
    expect(find.text('KeyVault is locked'), findsNothing);
  });

  testWidgets('failed reauthentication does not destroy unlocked content', (
    tester,
  ) async {
    final authenticationService = FakeAuthenticationService(
      authenticationResult: AuthenticationResult.success,
    );

    Future<bool> Function()? reauthenticate;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationGate(
          authenticationService: authenticationService,
          navigatorKey: navigatorKey,
          unlockedBuilder: (onLock, onReauthenticate) {
            reauthenticate = onReauthenticate;

            return const Scaffold(body: Text('Vault content'));
          },
        ),
      ),
    );

    // Explicitly unlock first.
    await tapUnlock(tester);

    expect(authenticationService.authenticationCallCount, 1);
    expect(find.text('Vault content'), findsOneWidget);
    expect(reauthenticate, isNotNull);

    // Make only the subsequent authentication fail.
    authenticationService.authenticationResult = AuthenticationResult.failed;

    final result = await reauthenticate!();

    await tester.pump();

    expect(result, isFalse);
    expect(authenticationService.authenticationCallCount, 2);

    // Failed reauthentication must preserve the existing UI.
    expect(find.text('Vault content'), findsOneWidget);
    expect(find.text('KeyVault is locked'), findsNothing);
  });
}
