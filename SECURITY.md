# Security Considerations

## Data Protection

### Database Encryption
Currently uses standard SQLite (unencrypted). For production deployment with sensitive data:

**Option 1: SQLCipher (sqlcipher_flutter)**
- Pros: Transparent encryption, minimal code changes
- Cons: Larger binary size, GPL license considerations

**Option 2: flutter_secure_storage for sensitive fields only**
- Current approach: Only DOB (Date of Birth) is stored in Settings table
- Use `flutter_secure_storage` for DOB, fallback to SQLite for other data
- See `lib/services/secure_storage_service.dart` for implementation

### Authentication
- No authentication required currently (personal app)
- Recommended: Add biometric/PIN lock for Life Tracker screen
- Use `local_auth` package for biometric/PIN authentication

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

## Recommendations for Production

1. **Enable SQLCipher** if storing sensitive financial/medical data
2. **Add local_auth** for Life Tracker screen protection
3. **Use flutter_secure_storage** for DOB and any future tokens
4. **Add app integrity checks** (Google Play Integrity / App Attest)
5. **Implement certificate pinning** if adding network calls
6. **Regular dependency updates** for security patches

## Reporting Security Issues
Report security issues privately via GitHub Security Advisories or email.

## Security Checklist
- [x] No hardcoded secrets
- [x] No network calls (local-first)
- [x] User data export capability
- [x] Runtime notification permission request
- [ ] Database encryption (SQLCipher)
- [ ] Biometric/PIN protection for sensitive screens
- [ ] Secure storage for sensitive fields