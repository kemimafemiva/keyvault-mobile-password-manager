import 'package:flutter/material.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:uuid/uuid.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';

class CredentialFormScreen extends StatefulWidget {
  final CredentialRepository repository;
  final Future<bool> Function() onReauthenticate;
  final Credential? credential;

  const CredentialFormScreen({
    super.key,
    required this.repository,
    required this.onReauthenticate,
    this.credential,
  });

  @override
  State<CredentialFormScreen> createState() => _CredentialFormScreenState();
}

class _CredentialFormScreenState extends State<CredentialFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _serviceController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSaving = false;

  bool get _isEditing => widget.credential != null;

  @override
  void initState() {
    super.initState();

    final credential = widget.credential;

    if (credential != null) {
      _serviceController.text = credential.serviceName;
      _usernameController.text = credential.username;
      _passwordController.text = credential.password;
      _websiteController.text = credential.website ?? '';
    }
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final credential = _buildCredential();

    try {
      final saved = await _saveCredential(credential);

      if (!saved || !mounted) {
        return;
      }

      Navigator.of(context).pop(credential);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Credential _buildCredential() {
    final now = DateTime.now();

    if (!_isEditing) {
      return Credential(
        id: const Uuid().v4(),
        serviceName: _serviceController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        website:
            _websiteController.text.trim().isEmpty
                ? null
                : _websiteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );
    }

    return Credential(
      id: widget.credential!.id,
      serviceName: _serviceController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      website:
          _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
      createdAt: widget.credential!.createdAt,
      updatedAt: now,
    );
  }

  Future<bool> _saveCredential(Credential credential) async {
    /*
     * Editing an existing credential is a deliberate
     * sensitive operation and therefore requires
     * reauthentication before the update is attempted.
     */
    if (_isEditing) {
      final authenticated = await widget.onReauthenticate();

      if (!authenticated) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication is required to edit this credential.',
            ),
          ),
        );

        return false;
      }

      try {
        await _persistCredential(credential);

        return true;
      } on AuthenticationRequiredException {
        /*
         * Authentication has already been deliberately
         * requested for Edit. Do not repeatedly prompt.
         */
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication is required to access the vault.'),
          ),
        );

        return false;
      }
    }

    /*
     * Adding a credential normally requires no additional
     * authentication because the vault has already been
     * unlocked.
     *
     * Android Keystore authentication can expire while the
     * user is completing the form. Therefore, first attempt
     * the save without another prompt.
     */
    try {
      await _persistCredential(credential);
      return true;
    } on AuthenticationRequiredException {
      /*
       * The platform key is no longer authorized.
       * Request authentication only when it is actually
       * required, then retry the save once.
       */
      final authenticated = await widget.onReauthenticate();

      if (!authenticated) {
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication is required to save this credential.',
            ),
          ),
        );

        return false;
      }

      try {
        await _persistCredential(credential);
        return true;
      } on AuthenticationRequiredException {
        /*
         * Do not enter an authentication retry loop if the
         * platform still refuses access after reauthentication.
         */
        if (!mounted) {
          return false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication is required to access the vault.'),
          ),
        );

        return false;
      }
    }
  }

  Future<void> _persistCredential(Credential credential) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (!_isEditing) {
        await widget.repository.addCredential(credential);

        stopwatch.stop();

        debugPrint(
          'PERF add_credential: '
          '${stopwatch.elapsedMicroseconds / 1000} ms',
        );
      } else {
        await widget.repository.updateCredential(credential);

        stopwatch.stop();

        debugPrint(
          'PERF edit_credential: '
          '${stopwatch.elapsedMicroseconds / 1000} ms',
        );
      }
    } finally {
      if (stopwatch.isRunning) {
        stopwatch.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Credential' : 'Add Credential'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _serviceController,
                decoration: const InputDecoration(
                  labelText: 'Service',
                  hintText: 'e.g. Gmail',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a service name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username or email',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a username or email.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isEditing ? _obscurePassword : false,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon:
                      !_isEditing
                          ? IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          )
                          : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter a password.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Website (optional)',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
