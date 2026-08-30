import 'package:flutter/material.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/exceptions/vault_access_exception.dart';
import 'package:key_vault/services/clipboard_service.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';
import 'credential_form_screen.dart';
import 'credential_details_screen.dart';

class VaultScreen extends StatefulWidget {
  final CredentialRepository repository;
  final VoidCallback onLock;
  final VoidCallback onAuthenticationRequired;
  final Future<bool> Function() onReauthenticate;

  const VaultScreen({
    super.key,
    required this.repository,
    required this.onLock,
    required this.onAuthenticationRequired,
    required this.onReauthenticate,
  });

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<Credential> _credentials = [];
  bool _isLoading = true;
  String? _loadError;
  final ClipboardService _clipboardService = ClipboardService();

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _clipboardService.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    try {
      final stopwatch = Stopwatch()..start();
      final credentials = await widget.repository.getCredentials();

      stopwatch.stop();

      debugPrint(
        'PERF credential_retrieval: '
        '${stopwatch.elapsedMicroseconds / 1000} ms',
      );

      if (!mounted) return;

      setState(() {
        _credentials = credentials;
        _loadError = null;
      });
    } on AuthenticationRequiredException {
      if (!mounted) return;

      widget.onAuthenticationRequired();
    } on VaultAccessException {
      if (!mounted) return;

      setState(() {
        _loadError = 'KeyVault could not access the encrypted vault.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addCredential() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CredentialFormScreen(
              repository: widget.repository,
              onReauthenticate: widget.onReauthenticate,
            ),
      ),
    );

    await _loadCredentials();
  }

  Future<void> _confirmResetVault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset KeyVault?'),
          content: const Text(
            'This will permanently delete the encrypted vault '
            'and its encryption key. Existing credentials cannot '
            'be recovered after this action.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Reset Vault'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _resetVault();
  }

  Future<void> _resetVault() async {
    try {
      await widget.repository.resetVault();

      if (!mounted) return;

      setState(() {
        _credentials = [];
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KeyVault could not be reset.')),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'The existing credentials cannot be recovered '
                'without the original encryption key.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: _confirmResetVault,
                child: const Text('Reset Vault'),
              ),
            ],
          ),
        ),
      );
    }

    if (_credentials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Your vault is empty',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first credential to get started.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _credentials.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final credential = _credentials[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 6,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_circle_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          title: Text(
            credential.serviceName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              credential.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => CredentialDetailsScreen(
                      credential: credential,
                      repository: widget.repository,
                      onReauthenticate: widget.onReauthenticate,
                      clipboardService: _clipboardService,
                    ),
              ),
            );

            await _loadCredentials();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KeyVault'),
        actions: [
          IconButton(
            onPressed: widget.onLock,
            tooltip: 'Lock vault',
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCredential,
        tooltip: 'Add credential',
        child: const Icon(Icons.add),
      ),
    );
  }
}
