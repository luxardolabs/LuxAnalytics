# LuxAnalytics Security Model

This document describes the security architecture and best practices for LuxAnalytics, a privacy-first iOS analytics SDK.

## Overview

LuxAnalytics is designed with security as a core principle. All data transmission is authenticated, encrypted in transit and at rest, with built-in PII filtering and optional certificate pinning.

## Security Features

### 1. HMAC-SHA256 Request Authentication

Every request to the analytics API is authenticated using HMAC-SHA256:

- **Algorithm**: HMAC-SHA256
- **Message**: Request body + timestamp
- **Headers**: 
  - `X-HMAC-Signature`: The computed HMAC signature
  - `X-Key-ID`: The API key identifier
  - `X-Timestamp`: Unix timestamp for replay protection

**Implementation**:
```swift
let key = SymmetricKey(data: Data(config.hmacSecret.utf8))
let message = payload + Data(timestamp.utf8)
let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
let signature = Data(mac).map { String(format: "%02x", $0) }.joined()
```

### 2. Queue Encryption (AES-GCM)

The event queue is encrypted at rest using AES-256-GCM:

- **Algorithm**: AES-256-GCM
- **Key Storage**: iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **Key Generation**: Automatic on first use
- **Fallback**: Unencrypted storage if encryption fails (with logging)

**Implementation**:
```swift
// Encryption
let sealedBox = try AES.GCM.seal(data, using: key)
return sealedBox.combined

// Decryption
let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
return try AES.GCM.open(sealedBox, using: key)
```

### 3. Certificate Pinning (Optional)

Certificate pinning provides protection against MITM attacks:

- **Hash Algorithm**: SHA256
- **Validation Options**:
  - Pin leaf certificate only
  - Pin entire certificate chain
  - Allow self-signed certificates (for testing)
- **Configuration**: Provide SHA256 hashes of certificates in base64

**Usage**:
```swift
let certificatePinning = CertificatePinningConfig(
    pinnedCertificateHashes: ["base64-sha256-hash"],
    allowSelfSigned: false,
    validateChain: true
)

let config = LuxAnalyticsConfiguration(
    // ... other config ...
    certificatePinning: certificatePinning
)
```

### 4. PII Filtering

Automatic detection and filtering of personally identifiable information:

- **Patterns Detected**:
  - Email addresses
  - Phone numbers
  - Credit card numbers
  - Social Security Numbers
  - IP addresses
  - URLs with potential PII

**Usage**:
```swift
// Automatic filtering in metadata
let filtered = PIIFilter.filterPII(from: metadata)

// Manual sanitization
let sanitized = PIIFilter.sanitize(text)
```

### 5. Secure Logging

All SDK logs automatically redact sensitive information:

- **Redacted**: API keys, secrets, user IDs, session IDs
- **Preserved**: Event names, timestamps, counts
- **Configurable**: Enable/disable debug logging

**Example**:
```swift
// Input: "Tracking event for user user123"
// Output: "Tracking event for user [REDACTED]"
```

### 6. Network Security

- **TLS**: Minimum TLS 1.2 required (iOS enforced)
- **Compression**: Optional gzip compression for large payloads
- **Timeouts**: Configurable request timeouts (default 30s)
- **Retry Logic**: Exponential backoff with jitter
- **Circuit Breaker**: Prevents hammering failed endpoints

## Security Best Practices

### 1. Credential Storage

**❌ NEVER**:
- Store credentials in Info.plist
- Commit secrets to source control
- Store credentials in UserDefaults
- Hard-code credentials in source code

**✅ ALWAYS**:
- Use iOS Keychain for credential storage
- Use environment injection for CI/CD
- Rotate credentials regularly
- Use separate credentials for development/production

**Example Keychain Storage**:
```swift
func storeInKeychain(_ secret: String, for key: String) -> Bool {
    let data = secret.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ]
    SecItemDelete(query as CFDictionary)
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
}
```

### 2. Data Minimization

- Only collect necessary data
- Avoid collecting user-identifiable information
- Use anonymous identifiers where possible
- Implement data retention policies

### 3. User Consent

- Always obtain user consent before tracking
- Provide clear opt-out mechanisms
- Respect user privacy settings

**Example**:
```swift
// Check user consent before initializing
if UserDefaults.standard.bool(forKey: "analytics_consent") {
    try LuxAnalytics.initialize(with: config)
}

// Provide opt-out
func optOutOfAnalytics() {
    AnalyticsSettings.shared.setEnabled(false)
    LuxAnalytics.clearQueue()
}
```

### 4. Development vs Production

- Use different API endpoints for development/production
- Enable certificate pinning in production
- Disable debug logging in production
- Use separate credentials

**Example**:
```swift
let config = LuxAnalyticsConfiguration(
    apiURL: isProduction ? prodURL : devURL,
    hmacSecret: getFromKeychain(isProduction ? "prod_secret" : "dev_secret"),
    keyID: getFromKeychain(isProduction ? "prod_key" : "dev_key"),
    debugLogging: !isProduction,
    certificatePinning: isProduction ? certificatePinning : nil
)
```

## Threat Model

### 1. Network Attacks

**Threat**: Man-in-the-middle attacks
**Mitigation**: 
- TLS encryption (enforced by iOS)
- Certificate pinning (optional)
- HMAC signature validation

**Threat**: Replay attacks
**Mitigation**: 
- Timestamp validation on server
- Event deduplication by ID

### 2. Local Storage Attacks

**Threat**: Queue data exposure on jailbroken devices
**Mitigation**: 
- AES-256-GCM encryption
- Keychain storage for encryption keys
- Automatic queue expiry (TTL)

**Threat**: Memory disclosure
**Mitigation**: 
- No storage of raw credentials in memory
- Automatic clearing of sensitive data
- Swift's memory safety features

### 3. Application Attacks

**Threat**: Malicious event injection
**Mitigation**: 
- HMAC authentication
- Input validation
- Rate limiting (server-side)

**Threat**: Information disclosure through logs
**Mitigation**: 
- Automatic log redaction
- Configurable debug logging
- No sensitive data in release builds

## Compliance Considerations

### GDPR Compliance

- User consent mechanisms
- Data minimization by default
- Right to erasure (clear queue)
- No PII collection by default

### App Store Privacy

- No third-party data sharing
- Optional identifiers only
- Transparent data collection
- User control over data

## Security Checklist

Before deploying to production:

- [ ] Credentials stored in Keychain
- [ ] Certificate pinning configured
- [ ] Debug logging disabled
- [ ] PII filtering tested
- [ ] User consent flow implemented
- [ ] Data retention policy defined
- [ ] Security headers configured on API
- [ ] Rate limiting enabled on API
- [ ] Timestamp validation on API
- [ ] HMAC validation on API

## Incident Response

If you suspect a security issue:

1. Disable analytics: `AnalyticsSettings.shared.setEnabled(false)`
2. Clear queue: `LuxAnalytics.clearQueue()`
3. Rotate credentials
4. Review server logs
5. Contact security team

## Security Contact

For security concerns or vulnerability reports:
- Email: security@luxardolabs.com
- PGP Key: [Available on request]

Please do not file public issues for security vulnerabilities.