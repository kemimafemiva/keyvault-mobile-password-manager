# KeyVault

KeyVault is a cross-platform mobile password manager prototype developed as part of a final-year Software Engineering project on **Security and Privacy of Mobile Password Managers**.

The prototype explores how modern mobile security mechanisms can be combined to protect locally stored login credentials while maintaining a practical user experience. It is implemented using Flutter, with native Android and iOS components for platform-specific cryptographic key protection, authentication, and privacy controls.

## Features

- Secure local storage of login credentials

- AES-256-GCM authenticated encryption

- Platform-protected encryption key management
  - Android Keystore
  - iOS Keychain

- Biometric and device authentication using `local_auth` and platform security mechanisms
  - Facial recognition or fingerprint authentication where supported
  - Device passcode/PIN fallback where supported
  - Re-authentication for sensitive credential operations

- In-memory encryption-key session management on iOS

- Automatic vault locking when the application enters the background

- Adaptive re-authentication when Android Keystore authorization expires

- Protection against modified ciphertext, nonce, and authentication tags

- Clipboard clearing after copying sensitive credential data

- Android screen-capture protection using `FLAG_SECURE`

- iOS privacy screen protection during application lifecycle transitions

- Secure vault reset when the encryption key is unavailable or inaccessible

- Local-only credential storage with no cloud synchronization

## Technology Stack

- Flutter
- Dart
- Kotlin
- Swift
- `local_auth`
- Android Keystore
- iOS Keychain
- AES-256-GCM
- Flutter Method Channels
- Native Android and iOS security APIs

## Security Design

KeyVault follows a layered security approach combining authenticated encryption, platform-protected key management, device authentication, session management, and application-level privacy controls.

Credential data is serialized and encrypted using AES-256-GCM before being persisted. AES-GCM provides both confidentiality and integrity protection, allowing the application to detect modifications to encrypted credential data, including changes to ciphertext, nonces, and authentication tags.

Encryption keys are kept separate from the encrypted credential data and protected using platform-specific secure storage mechanisms. Android uses the Android Keystore, while iOS uses the iOS Keychain. The encryption key is not stored with the encrypted vault data.

### Authentication

KeyVault uses the Flutter `local_auth` package together with platform-specific key protection to implement biometric and device authentication.

On Android, `local_auth` is used to authenticate the user before the vault is unlocked. The AES encryption key remains protected by the Android Keystore and is configured with an authentication validity period. After successful authentication, Keystore operations can use the protected key during the configured authorization window.

On a physical iOS device, vault unlocking retrieves the AES encryption key from an iOS Keychain item protected using `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` and `.userPresence`. Accessing the protected Keychain item therefore requires user authentication before the encryption session can be opened.

After successful iOS authentication, the retrieved `SymmetricKey` is retained only in memory for the duration of the unlocked session. Routine encryption and decryption operations use this session key rather than repeatedly retrieving the key from the Keychain. Locking the vault or moving the application into the background clears the in-memory session key.

Editing and deleting credentials are considered sensitive operations and require deliberate re-authentication using `local_auth`.

### Android Authentication Expiry

The Android Keystore encryption key uses a 30-second authentication validity window. This allows cryptographic operations to occur for a limited period following successful authentication without requiring the user to authenticate for every operation.

Adding a credential does not normally trigger an additional authentication request immediately after unlocking the vault. However, if the Keystore authorization expires while the user is completing the credential form, KeyVault detects the authentication-required condition, requests authentication using `local_auth`, and retries the save operation once.

This adaptive approach reduces unnecessary authentication prompts while ensuring that cryptographic operations continue to respect the security restrictions enforced by the Android Keystore.

### iOS Simulator Authentication

The iOS Simulator does not consistently enforce the `.userPresence` Keychain authentication prompt in the same way as a physical iOS device. During testing, a protected Keychain item could be successfully retrieved by `SecItemCopyMatching` on the Simulator without presenting the simulated Face ID interface, while the same implementation correctly required Face ID on a physical iPhone.

To provide a representative and testable authentication workflow on the iOS Simulator, KeyVault explicitly uses `local_auth` before unlocking the cryptographic session when running in the Simulator. Physical iOS devices continue to rely on the `.userPresence`-protected Keychain item for the initial vault authentication.

This Simulator-specific behaviour supports automated testing without weakening or replacing the Keychain protection used on physical devices.

### Privacy Protection

KeyVault automatically locks when moved to the background. On iOS, this also clears the in-memory encryption-key session so that returning to the application requires the protected session to be unlocked again.

Platform-specific privacy controls are applied to reduce exposure of credential information when the application is not actively being used. Android uses `FLAG_SECURE` to restrict screenshots and screen recording, while iOS displays privacy protection during application lifecycle transitions.

Sensitive credential values copied to the clipboard are automatically cleared after a limited period to reduce unintended exposure.

## Project Scope

KeyVault is a research and educational proof of concept rather than a production password manager.

The prototype was developed to investigate:

- Encryption practices used by mobile password managers
- Secure cryptographic key storage
- Biometric and device authentication
- Protection of sensitive information during application lifecycle transitions
- Potential security and privacy vulnerabilities
- Security and usability trade-offs in password manager design

Features commonly found in commercial password managers, such as cloud synchronization, browser integration, credential autofill, password sharing, and account recovery, are intentionally outside the scope of the prototype.

## Testing

The prototype includes automated tests across the Flutter and native platform layers.

Testing covers areas including:

- Credential encryption and decryption
- Rejection of modified ciphertext
- Rejection of modified authentication tags
- Rejection of modified nonces
- Authentication-required behaviour
- Credential repository operations
- Verification that plaintext credential data is not persisted
- Encryption-key deletion and vault reset
- Application lifecycle locking
- Native Flutter method-channel communication
- Error and recovery behaviour
- Biometric authentication workflows
- Credential add, edit, retrieval, and deletion workflows

Manual testing was also performed on Android and physical iOS devices to evaluate authentication flows, background locking, privacy protection, and credential-management workflows.

Automated UI and performance testing uses Android Emulator and iOS Simulator environments. Simulated biometric authentication is used where required to reproduce the authentication workflows during automated testing.

## Running the Project

Ensure Flutter and the required Android/iOS development tools are installed.

Install the Flutter dependencies:

```bash
flutter pub get
```

Run the application on a connected device, simulator, or emulator:

```bash
flutter run
```

Biometric authentication requires a device or simulator/emulator configured with supported biometric authentication or device credentials.

For iOS Simulator testing, Face ID can be enrolled through the Simulator's biometric configuration. KeyVault uses `local_auth` for the Simulator unlock flow so that simulated Face ID authentication can be exercised during manual and automated testing.

## Disclaimer

This application was developed for academic research and demonstration purposes. It has not undergone the extensive security auditing, penetration testing, or production hardening expected of a commercial password manager.

It should not be used to store real or sensitive credentials.

## Academic Project

**Project Title:** Security and Privacy of Mobile Password Managers  
**Prototype:** KeyVault  
**Application Area:** Mobile Security and Personal Data Protection