import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:key_vault/models/authentication_result.dart';

import '../services/authentication_service.dart';
import '../services/native_crypto_service.dart';
import 'lock_screen.dart';

class AuthenticationGate extends StatefulWidget {
  final AuthenticationService authenticationService;
  final NativeCryptoService cryptoService;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget Function(
    VoidCallback onLock,
    Future<bool> Function() onReauthenticate,
    Future<bool> Function() onSessionExpired,
  )
  unlockedBuilder;

  const AuthenticationGate({
    super.key,
    required this.authenticationService,
    required this.cryptoService,
    required this.navigatorKey,
    required this.unlockedBuilder,
  });

  @override
  State<AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<AuthenticationGate>
    with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _showPrivacyOverlay = false;
  bool _didEnterBackground = false;

  static const _privacyChannel = MethodChannel(
    'com.oluwakemimafe.keyvault/privacy',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _unlock() async {
    await widget.cryptoService.unlockSession();

    if (!mounted) return;

    setState(() {
      _isUnlocked = true;
    });
  }

  Future<void> _lock() async {
    if (!_isUnlocked) return;

    try {
      await widget.cryptoService.lockSession();
    } catch (_) {
      // Continue locking the Flutter UI even if native session cleanup fails.
    }

    if (!mounted) return;

    widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);

    setState(() {
      _isUnlocked = false;
    });
  }

  Future<bool> _reAuthenticate() async {
    try {
      final result = await widget.authenticationService.authenticate();

      if (result != AuthenticationResult.success) {
        return false;
      }

      await widget.cryptoService.renewSession();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _recoverExpiredSession() async {
    try {
      if (Platform.isIOS) {
        await widget.cryptoService.unlockSession();
        return true;
      }

      final result = await widget.authenticationService.authenticate();

      if (result != AuthenticationResult.success) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  void _revealAfterTemporaryInactivity() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      setState(() {
        _showPrivacyOverlay = false;
      });

      try {
        await _privacyChannel.invokeMethod('hidePrivacyOverlay');
      } on MissingPluginException {
        // Native privacy channel is not available.
      }
    });
  }

  Future<void> _revealAfterBackgroundLock() async {
    // Wait until Flutter has finished the current frame.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    setState(() {
      _showPrivacyOverlay = false;
    });

    // Wait for the frame containing the safe locked UI
    // without the Flutter overlay.
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) return;

    try {
      await _privacyChannel.invokeMethod('hidePrivacyOverlay');
    } on MissingPluginException {
      // Native privacy channel is not available.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.inactive:
        setState(() {
          _showPrivacyOverlay = true;
        });
        break;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _didEnterBackground = true;

        setState(() {
          _showPrivacyOverlay = true;
        });

        unawaited(_lock());
        break;

      case AppLifecycleState.detached:
        _didEnterBackground = true;
        unawaited(_lock());
        break;

      case AppLifecycleState.resumed:
        if (_didEnterBackground) {
          _didEnterBackground = false;
          unawaited(_revealAfterBackgroundLock());
        } else {
          _revealAfterTemporaryInactivity();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (!_isUnlocked) {
      content = LockScreen(
        authenticationService: widget.authenticationService,
        cryptoService: widget.cryptoService,
        onAuthenticated: _unlock,
      );
    } else {
      content = widget.unlockedBuilder(
        () {
          unawaited(_lock());
        },
        _reAuthenticate,
        _recoverExpiredSession,
      );
    }

    return Stack(
      children: [
        content,
        if (_showPrivacyOverlay)
          const Positioned.fill(
            child: ColoredBox(key: Key('privacy-overlay'), color: Colors.black),
          ),
      ],
    );
  }
}
