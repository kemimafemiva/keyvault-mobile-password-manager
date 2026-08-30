import 'dart:io';

import 'package:flutter/material.dart';
import 'package:key_vault/models/authentication_result.dart';
import 'package:key_vault/services/native_crypto_service.dart';
import 'package:local_auth/local_auth.dart';

import '../services/authentication_service.dart';
import '../theme/key_vault_theme.dart';

class LockScreen extends StatefulWidget {
  final AuthenticationService authenticationService;
  final NativeCryptoService cryptoService;
  final Future<void> Function() onAuthenticated;

  const LockScreen({
    super.key,
    required this.authenticationService,
    required this.cryptoService,
    required this.onAuthenticated,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  BiometricType? _biometricType;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBiometricType();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      if (Platform.isIOS && !await widget.cryptoService.isSimulator()) {
        /*
   * On a physical iOS device, unlocking the crypto session
   * retrieves the .userPresence-protected Keychain encryption
   * key. Keychain therefore performs the authentication itself.
   *
   * The iOS Simulator does not consistently enforce the
   * Keychain user-presence prompt, so it uses the local_auth
   * flow below instead.
   */
        await widget.onAuthenticated();
      } else {
        final result = await widget.authenticationService.authenticate();

        if (!mounted) return;

        if (result == AuthenticationResult.success) {
          await widget.onAuthenticated();
        } else {
          setState(() {
            _errorMessage = 'Authentication failed or was cancelled.';
          });
        }
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Authentication failed or was cancelled.';
      });
    } finally {
      stopwatch.stop();

      debugPrint(
        'PERF vault_authentication: '
        '${stopwatch.elapsedMicroseconds / 1000} ms',
      );

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _loadBiometricType() async {
    final biometrics =
        await widget.authenticationService.getAvailableBiometrics();

    if (!mounted || biometrics.isEmpty) {
      return;
    }

    setState(() {
      if (biometrics.contains(BiometricType.face)) {
        _biometricType = BiometricType.face;
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        _biometricType = BiometricType.fingerprint;
      } else {
        _biometricType = biometrics.first;
      }
    });
  }

  IconData get _authenticationIcon {
    switch (_biometricType) {
      case BiometricType.face:
        return Icons.face;

      case BiometricType.fingerprint:
        return Icons.fingerprint;

      default:
        return Icons.password;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 72,
                  color: keyVaultPrimary,
                ),
                const SizedBox(height: 24),
                Text(
                  'KeyVault is locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: keyVaultPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Authenticate to access your credentials.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _isAuthenticating ? null : _authenticate,
                    icon: Icon(_authenticationIcon),
                    label: Text(
                      _isAuthenticating ? 'Authenticating...' : 'Unlock',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
