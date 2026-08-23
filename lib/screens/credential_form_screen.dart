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
      final saved = await _saveCredentialWithReauthentication(credential);

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

    if (widget.credential == null) {
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

  Future<bool> _saveCredentialWithReauthentication(
    Credential credential,
  ) async {
    try {
      await _persistCredential(credential);
      return true;
    } on AuthenticationRequiredException {
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

      // Authentication succeeded. Retry exactly once.
      await _persistCredential(credential);

      return true;
    }
  }

  Future<void> _persistCredential(Credential credential) async {
    if (widget.credential == null) {
      await widget.repository.addCredential(credential);
    } else {
      await widget.repository.updateCredential(credential);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.credential == null ? 'Add Credential' : 'Edit Credential',
        ),
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
                obscureText:
                    widget.credential == null ? _obscurePassword : false,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon:
                      widget.credential == null
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
