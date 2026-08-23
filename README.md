# KeyVault

KeyVault is a cross-platform mobile password manager prototype developed as part of a final-year Software Engineering project on **Security and Privacy of Mobile Password Managers**.

The prototype explores how modern mobile security mechanisms can be combined to protect locally stored login credentials while maintaining a practical user experience. It is implemented using Flutter, with native Android and iOS components for platform-specific cryptographic key protection and privacy controls.

## Features

- Secure local storage of login credentials
- AES-256-GCM authenticated encryption
- Platform-protected encryption key management
  - Android Keystore
  - iOS Keychain
- Biometric authentication using Face ID or fingerprint
- Device credential/PIN fallback where supported
- Automatic vault locking when the application enters the background
- Re-authentication for protected operations
- Protection against modified ciphertext, nonce, and authentication tags
- Clipboard clearing after copying sensitive credential data
- Android screen-capture protection using `FLAG_SECURE`
- iOS privacy screen protection during application lifecycle transitions
- Secure vault reset when the encryption key is unavailable
- Local-only credential storage with no cloud synchronization

## Technology Stack

- Flutter
- Dart
- Kotlin
- Swift
- Android Keystore
- iOS Keychain
- AES-256-GCM
- `local_auth`
- `flutter_secure_storage`

## Security Design

KeyVault follows a layered security approach.

Credential data is serialized and encrypted using AES-256-GCM before being persisted. AES-GCM provides both confidentiality and integrity protection, allowing the application to detect modifications to encrypted data.

Encryption keys are kept separate from the encrypted credential data and protected using platform-specific secure storage mechanisms. Android uses the Android Keystore, while iOS uses the Keychain.

Access to the vault is protected through device authentication. Where available, users can authenticate using biometrics such as Face ID or fingerprint recognition, with device credentials used as a fallback where supported.

The application also automatically locks when moved to the background and applies platform-specific privacy protections to reduce the risk of credential information being exposed through application previews or screen capture.

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

Manual testing was also performed on Android and iOS to evaluate authentication flows, background locking, privacy protection, and credential-management workflows.

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

## Disclaimer

This application was developed for academic research and demonstration purposes. It has not undergone the extensive security auditing, penetration testing, or production hardening expected of a commercial password manager.

It should not be used to store real or sensitive credentials.

## Academic Project

**Project Title:** Security and Privacy of Mobile Password Managers  
**Prototype:** KeyVault  
**Application Area:** Mobile Security and Personal Data Protection