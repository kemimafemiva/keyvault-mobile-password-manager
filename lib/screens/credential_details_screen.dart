import 'package:flutter/material.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:key_vault/services/clipboard_service.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';
import 'credential_form_screen.dart';
import '../widgets/detail_item.dart';

class CredentialDetailsScreen extends StatefulWidget {
  final Credential credential;
  final CredentialRepository repository;
  final ClipboardService clipboardService;
  final Future<bool> Function() onReauthenticate;

  const CredentialDetailsScreen({
    super.key,
    required this.credential,
    required this.repository,
    required this.clipboardService,
    required this.onReauthenticate,
  });

  @override
  State<CredentialDetailsScreen> createState() =>
      _CredentialDetailsScreenState();
}

class _CredentialDetailsScreenState extends State<CredentialDetailsScreen> {
  late Credential _credential;
  bool _showPassword = false;

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
            ),
      ),
    );

    if (updatedCredential == null || !mounted) {
      return;
    }

    setState(() {
      _credential = updatedCredential;
      _showPassword = false;
    });
  }

  Future<void> _deleteCredential() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete credential?'),
          content: Text(
            'Delete the credential for ${_credential.serviceName}?',
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

    if (shouldDelete != true) {
      return;
    }

    try {
      await widget.repository.deleteCredential(_credential.id);
    } on AuthenticationRequiredException {
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

      // Authentication succeeded. Retry once.
      await widget.repository.deleteCredential(_credential.id);
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_credential.serviceName),
        actions: [
          IconButton(
            onPressed: _editCredential,
            tooltip: 'Edit credential',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _deleteCredential,
            tooltip: 'Delete credential',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
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
        ],
      ),
    );
  }
}
