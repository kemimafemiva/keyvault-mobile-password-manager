import 'package:key_vault/services/credential_storage_service.dart';

class FakeCredentialStorageService extends CredentialStorageService {
  String? storedValue;

  @override
  Future<void> write(String encryptedVault) async {
    storedValue = encryptedVault;
  }

  @override
  Future<String?> read() async {
    return storedValue;
  }

  @override
  Future<bool> exists() async {
    return storedValue != null;
  }

  @override
  Future<void> delete() async {
    storedValue = null;
  }
}
