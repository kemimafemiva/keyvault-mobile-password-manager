import 'package:flutter/material.dart';
import 'package:key_vault/screens/vault_screen.dart';
import 'package:key_vault/services/native_crypto_service.dart';
import 'package:key_vault/theme/key_vault_theme.dart';

import '../repositories/credential_repository.dart';
import '../services/credential_storage_service.dart';
import '../screens/authentication_gate.dart';
import '../services/authentication_service.dart';

class KeyVaultApp extends StatelessWidget {
  KeyVaultApp({super.key});

  final NativeCryptoService _cryptoService = NativeCryptoService();

  late final CredentialRepository _repository = CredentialRepository(
    cryptoService: _cryptoService,
    storageService: CredentialStorageService(),
  );

  final AuthenticationService _authenticationService = AuthenticationService();

  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'KeyVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: keyVaultPrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: keyVaultPrimary,
          secondary: keyVaultSecondary,
          surface: keyVaultSurface,
        ),
        scaffoldBackgroundColor: keyVaultSurface,
        appBarTheme: const AppBarTheme(
          backgroundColor: keyVaultPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: keyVaultPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: keyVaultPrimary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: keyVaultPrimary, width: 2),
          ),
        ),
        useMaterial3: true,
      ),
      home: AuthenticationGate(
        authenticationService: _authenticationService,
        cryptoService: _cryptoService,
        navigatorKey: navigatorKey,
        unlockedBuilder: (onLock, onReauthenticate) {
          return VaultScreen(
            repository: _repository,
            onLock: onLock,
            onAuthenticationRequired: onLock,
            onReauthenticate: onReauthenticate,
          );
        },
      ),
    );
  }
}
