import 'package:flutter/material.dart';
import 'package:key_vault/exceptions/authentication_required_exception.dart';
import 'package:uuid/uuid.dart';

import '../models/credential.dart';
import '../repositories/credential_repository.dart';

class CredentialFormScreen extends StatefulWidget {
  final CredentialRepository repository;
  final Future<bool> Function() onReauthenticate;
  final Future<bool> Function() onSessionExpired;
  final Credential? credential;

  const CredentialFormScreen({
    super.key,
    required this.repository,
    required this.onReauthenticate,
    required this.onSessionExpired,
    this.credential,
  });

  @override
  State<CredentialFormScreen> createState() => _CredentialFormScreenState();
}

class _CredentialFormScreenState extends State<CredentialFormScreen> {
  static const int _minimumServiceNameLength = 2;
  static const int _maximumServiceNameLength = 100;
  static const int _minimumUsernameOrEmailLength = 2;
  static const int _maximumUsernameOrEmailLength = 254;
  static const int _minimumPasswordLength = 8;
  static const int _maximumPasswordLength = 128;
  static const int _maximumWebsiteLength = 2048;

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

  bool get _isEditing => widget.credential != null;

  bool _containsUppercase(String password) {
    return RegExp(r'[A-Z]').hasMatch(password);
  }

  bool _containsNumber(String password) {
    return RegExp(r'[0-9]').hasMatch(password);
  }

  bool _containsSpecialCharacter(String password) {
    return RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);
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

  String? _validateServiceName(String? value) {
    final input = value?.trim() ?? '';
    final issues = <String>[];

    if (input.length < _minimumServiceNameLength) {
      issues.add('at least $_minimumServiceNameLength characters');
    }

    if (input.length > _maximumServiceNameLength) {
      issues.add('no more than $_maximumServiceNameLength characters');
    }

    if (issues.isEmpty) {
      return null;
    }

    return 'Service name must include:\n'
        '${issues.map((issue) => '• $issue').join('\n')}';
  }

  String? _validateUsernameOrEmail(String? value) {
    final input = value?.trim() ?? '';
    final issues = <String>[];

    if (input.length < _minimumUsernameOrEmailLength) {
      issues.add('at least $_minimumUsernameOrEmailLength characters');
    }

    if (input.length > _maximumUsernameOrEmailLength) {
      issues.add('no more than $_maximumUsernameOrEmailLength characters');
    }

    if (issues.isEmpty) {
      return null;
    }

    return 'Username or email must include:\n'
        '${issues.map((issue) => '• $issue').join('\n')}';
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    final issues = <String>[];

    if (password.length < _minimumPasswordLength) {
      issues.add('at least $_minimumPasswordLength characters');
    }

    if (password.length > _maximumPasswordLength) {
      issues.add('no more than $_maximumPasswordLength characters');
    }

    if (!_containsUppercase(password)) {
      issues.add('an uppercase letter');
    }

    if (!_containsNumber(password)) {
      issues.add('a number');
    }

    if (!_containsSpecialCharacter(password)) {
      issues.add('a special character');
    }

    if (issues.isEmpty) {
      return null;
    }

    return 'Password must include:\n'
        '${issues.map((issue) => '• $issue').join('\n')}';
  }

  String? _validateWebsite(String? value) {
    final input = value?.trim() ?? '';

    // Website is optional.
    if (input.isEmpty) {
      return null;
    }

    final issues = <String>[];

    if (input.length > _maximumWebsiteLength) {
      issues.add('no more than $_maximumWebsiteLength characters');
    }

    final uri = Uri.tryParse(input);

    final hasValidUrl =
        uri != null &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');

    if (!hasValidUrl) {
      issues.add('a valid URL starting with http:// or https://');
    }

    if (issues.isEmpty) {
      return null;
    }

    return 'Website must include:\n'
        '${issues.map((issue) => '• $issue').join('\n')}';
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
      final authenticated = await widget.onSessionExpired();

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
                decoration: InputDecoration(
                  labelText: 'Service',
                  hintText: 'e.g. Gmail',
                  helperText:
                      '$_minimumServiceNameLength–'
                      '$_maximumServiceNameLength characters.',
                ),
                validator: _validateServiceName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username or email',
                  helperText:
                      '$_minimumUsernameOrEmailLength–'
                      '$_maximumUsernameOrEmailLength characters.',
                  errorMaxLines: 4,
                ),
                validator: _validateUsernameOrEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isEditing ? _obscurePassword : false,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText:
                      '$_minimumPasswordLength–$_maximumPasswordLength characters, '
                      'including an uppercase letter, a number, '
                      'and a special character.',
                  helperMaxLines: 2,
                  errorMaxLines: 6,
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
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Website (optional)',
                  hintText: 'https://example.com',
                  helperText: 'Maximum $_maximumWebsiteLength characters.',
                  errorMaxLines: 4,
                ),
                validator: _validateWebsite,
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
