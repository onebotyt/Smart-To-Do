# Security & Privacy

- Pair devices by **QR code or confirmation code**; exchange public keys at pairing.
- Only paired devices may connect; reject and log (without content) all others.
- Encrypt in transit with an **established protocol/library** (e.g. TLS with pinned peer keys, or Noise). **Never invent custom cryptography.**
- Store keys in platform secure storage (Android Keystore, Windows DPAPI/Credential Locker, Keychain).
- Never log task content or clipboard contents.
- Users can revoke a device; revoked devices must be rejected immediately.
- Validate every inbound message against a schema; use replay protection and integrity checks.
- Clipboard sharing is **opt-in**, has a clear pause control, shares plain text only, keeps one latest item, and deduplicates to prevent loops.
- Local-only does not mean secure: design encryption-at-rest options, permissions and backup behaviour deliberately.
- Security-sensitive code (pairing, crypto, sync apply) must be reviewed by a human before release.
