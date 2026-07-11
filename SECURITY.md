# Security Considerations

## Data Protection

### Database Encryption
**Implemented: SQLCipher via `sqflite_sqlcipher`**
- All data encrypted at rest using AES-256-CBC
- Encryption key stored in platform secure enclave via `flutter_secure_storage`
  - iOS: Keychain with Secure Enclave
  - Android: Android Keystore with Hardware-backed keys
- Automatic migration: plaintext SQLite → encrypted on first launch after update (migration version 5)
- Key derivation: 256-bit key generated once and stored securely
- **No plaintext database is written to disk after migration**

### Authentication
- **Implemented**: Biometric/PIN lock for Life Tracker screen (optional, in Settings)
- Uses `local_auth` package for biometric/PIN authentication
- User can enable/disable in Settings → Life Tracker section

### Data Export/Import
- JSON export/import implemented in Settings
- All data (notes, habits, events, calculator history, life data) can be exported
- No vendor lock-in - user owns their data

## Network Security
- No network calls in current implementation
- No external API keys or secrets in code
- All data stays local on device

## Notification Security
- Uses `flutter_local_notifications` with exact scheduling
- Notifications contain event title and notes (user data)
- No sensitive data in notifications
- Runtime permission request with rationale dialog (Android 13+)

## Key Management
- Database encryption key: generated on first launch, stored in platform secure enclave
- Never exported, backed up, or transmitted
- `flutter_secure_storage` handles key rotation and invalidation on biometric changes
- Key is not accessible from other apps or processes

## Security Checklist
- [x] No hardcoded secrets
- [x] No network calls (local-first)
- [x] User data export capability
- [x] Runtime notification permission request with rationale
- [x] Database encryption (SQLCipher + AES-256-CBC)
- [x] Biometric/PIN protection for sensitive screens
- [x] Secure storage for encryption key (platform keychain/keystore)
- [x] No plaintext database on disk after migration

## Recommendations for Production
1. ~~Enable SQLCipher~~ **Done**
2. ~~Add local_auth~~ **Done**
3. ~~Use flutter_secure_storage~~ **Done**
4. Add app integrity checks (Google Play Integrity / App Attest)
5. Implement certificate pinning if adding network calls
6. Regular dependency updates for security patches

## Reporting Security Issues
Report security issues privately via GitHub Security Advisories or email.
