import Foundation
import CryptoKit

/// Configuration for certificate pinning
public struct CertificatePinningConfig: Sendable {
    /// SHA256 hashes of pinned certificates (in base64)
    public let pinnedCertificateHashes: Set<String>
    
    /// Whether to allow self-signed certificates
    public let allowSelfSigned: Bool
    
    /// Whether to validate the entire certificate chain
    public let validateChain: Bool
    
    public init(
        pinnedCertificateHashes: Set<String>,
        allowSelfSigned: Bool = false,
        validateChain: Bool = true
    ) {
        self.pinnedCertificateHashes = pinnedCertificateHashes
        self.allowSelfSigned = allowSelfSigned
        self.validateChain = validateChain
    }
}

/// URLSession delegate for certificate pinning
final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let config: CertificatePinningConfig?
    
    init(config: CertificatePinningConfig?) {
        self.config = config
        super.init()
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let config = config,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            // No pinning configured or not a server trust challenge
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Evaluate server trust
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        
        if !isValid && !config.allowSelfSigned {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get certificate chain
        var certificateHashes: Set<String> = []
        
        if let certificates = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] {
            for (index, certificate) in certificates.enumerated() {
            
            // Get certificate data
            let certificateData = SecCertificateCopyData(certificate) as Data
            
            // Calculate SHA256 hash
            let hash = SHA256.hash(data: certificateData)
            let hashBase64 = Data(hash).base64EncodedString()
            certificateHashes.insert(hashBase64)
            
                // If we're not validating the chain, only check the leaf certificate
                if !config.validateChain && index == 0 {
                    break
                }
            }
        }
        
        // Check if any pinned certificate matches
        if !config.pinnedCertificateHashes.isEmpty {
            let matchFound = !config.pinnedCertificateHashes.isDisjoint(with: certificateHashes)
            
            if matchFound {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else {
            // No pins configured, accept if trust evaluation passed
            if isValid || config.allowSelfSigned {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }
}

// MARK: - Configuration Extension

// MARK: - URLSession Extension

extension URLSession {
    /// Create a URLSession with certificate pinning
    static func analyticsSession(with config: CertificatePinningConfig?) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = LuxAnalyticsConfiguration.current?.requestTimeout ?? LuxAnalyticsDefaults.requestTimeout
        
        let delegate = CertificatePinningDelegate(config: config)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
}