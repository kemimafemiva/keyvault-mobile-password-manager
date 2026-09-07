import 'package:flutter/material.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/services/clipboard_service.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';
import '../widgets/detail_item.dart';
import 'credential_form_screen.dart';

class CredentialDetailsScreen extends StatefulWidget {
  final Credential credential;
  final CredentialRepository repository;
  final ClipboardService clipboardService;
  final Future<bool> Function() onReauthenticate;
  final Future<bool> Function() onSessionExpired;

  const CredentialDetailsScreen({
    super.key,
    required this.credential,
    required this.repository,
    required this.clipboardService,
    required this.onReauthenticate,
    required this.onSessionExpired,
  });

  @override
  State<CredentialDetailsScreen> createState() =>
      _CredentialDetailsScreenState();
}

class _CredentialDetailsScreenState extends State<CredentialDetailsScreen> {
  late Credential _credential;
  bool _showPassword = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _credential = widget.credential;
  }

  Future<void> _copyUsername() async {
    await widget.clipboardService.copy(_credential.username);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Username copied')));
  }

  Future<void> _copyPassword() async {
    await widget.clipboardService.copySensitive(_credential.password);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password copied. Clipboard will clear in 30 seconds.'),
      ),
    );
  }

  Future<void> _editCredential() async {
    final updatedCredential = await Navigator.of(context).push<Credential>(
      MaterialPageRoute(
        builder:
            (_) => CredentialFormScreen(
              repository: widget.repository,
              credential: _credential,
              onReauthenticate: widget.onReauthenticate,
              onSessionExpired: widget.onSessionExpired,
            ),
      ),
    );

    if (updatedCredential == null || !mounted) {
      return;
    }

    /*
     * The credential has already been persisted by
     * CredentialFormScreen. Return to the vault and
     * signal that its credential list should refresh.
     */
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteCredential() async {
    if (_isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete credential?'),
          content: Text(
            'Delete the credential for '
            '${_credential.serviceName}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    /*
     * Deleting an existing credential is a
     * destructive operation, so require one
     * deliberate re-authentication.
     */
    final authenticated = await widget.onReauthenticate();

    if (!authenticated) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Authentication is required to delete this credential.',
          ),
        ),
      );

      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _persistDelete();
    } on AuthenticationRequiredException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication is required to access the vault.'),
        ),
      );

      return;
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    /*
     * Return to the vault and signal that
     * the credential list should refresh.
     */
    Navigator.of(context).pop(true);
  }

  Future<void> _persistDelete() async {
    final stopwatch = Stopwatch()..start();

    try {
      await widget.repository.deleteCredential(_credential.id);

      stopwatch.stop();

      debugPrint(
        'PERF delete_credential: '
        '${stopwatch.elapsedMicroseconds / 1000} ms',
      );
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_credential.serviceName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: DetailItem(
              label: 'Username or email',
              value: _credential.username,
              trailing: IconButton(
                onPressed: _copyUsername,
                tooltip: 'Copy username',
                icon: const Icon(Icons.copy_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Password', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showPassword ? _credential.password : '••••••••••••',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _copyPassword,
                      tooltip: 'Copy password',
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                      tooltip:
                          _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_credential.website != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: DetailItem(label: 'Website', value: _credential.website!),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _editCredential,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _deleteCredential,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
