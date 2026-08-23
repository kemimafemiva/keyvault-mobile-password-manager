import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CredentialStorageService {
  static const String _vaultFileName = 'vault.json';

  Future<File> _getVaultFile() async {
    final directory = await getApplicationDocumentsDirectory();

    return File('${directory.path}/$_vaultFileName');
  }

  Future<void> write(String encryptedVault) async {
    final file = await _getVaultFile();

    await file.writeAsString(encryptedVault, flush: true);
  }

  Future<String?> read() async {
    final file = await _getVaultFile();

    if (!await file.exists()) {
      return null;
    }

    return file.readAsString();
  }

  Future<bool> exists() async {
    final file = await _getVaultFile();

    return file.exists();
  }

  Future<void> delete() async {
    final file = await _getVaultFile();

    if (await file.exists()) {
      await file.delete();
    }
  }
}
