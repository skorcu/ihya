import Foundation
import CommonCrypto
import Combine

public enum LicenseTier: String, Codable, Sendable {
    case free = "Ücretsiz"
    case trial = "Pro Deneme (15 Gün)"
    case proLifetime = "İhyâ Pro (Ömür Boyu)"
}

public final class LicenseManager: ObservableObject, @unchecked Sendable {
    public static let shared = LicenseManager()
    
    // Tanıtım Dönemi: İhyâ lansmanında tüm Pro özellikler açık olarak başlar
    public static var promotionalFreeAccessActive: Bool {
        LicenseManager.shared.isPromotionalProActive
    }
    
    private static let masterSalt = "IHYA_MAC_CLEANER_PRO_2026_MASTER_SECRET_SALT_7b9d1e4c3a2f8015"
    public static let serverBaseURL: String = "https://caneser.com"
    
    private let defaults = UserDefaults.standard
    private let licenseKeyPrefKey = "ihya_pro_license_key"
    private let licenseStatusPrefKey = "ihya_pro_license_active"
    private let promoStatusPrefKey = "ihya_promo_pro_active"
    private let trialStartPrefKey = "ihya_trial_start_timestamp"
    private let lastKnownTimePrefKey = "ihya_last_known_timestamp"
    public static let trialTotalDays: Int = 15
    
    @Published public private(set) var activeLicenseKey: String = ""
    @Published public private(set) var hasPersonalLicense: Bool = false
    @Published public private(set) var isPromotionalProActive: Bool = false
    @Published public private(set) var isTrialActive: Bool = false
    @Published public private(set) var trialDaysRemaining: Int = 15
    @Published public private(set) var isTrialExpired: Bool = false
    @Published public private(set) var trialStartDate: Date? = nil
    @Published public private(set) var isProUnlocked: Bool = true
    @Published public private(set) var licenseTier: LicenseTier = .trial
    @Published public private(set) var hwidGrantTitle: String? = nil
    @Published public private(set) var hwidGrantExpiresAt: String? = nil
    
    private init() {
        loadSavedLicense()
        Task {
            await syncRemotePromoStatus()
            await autoRestoreHardwareLicense()
        }
    }
    
    private func initTrialState() {
        let now = Date()
        
        var startDate = KeychainHelper.loadTrialStartDate()
        if startDate == nil, let savedTs = defaults.object(forKey: trialStartPrefKey) as? Double {
            startDate = Date(timeIntervalSince1970: savedTs)
            KeychainHelper.saveTrialStartDate(startDate!)
        }
        
        if startDate == nil {
            startDate = now
            KeychainHelper.saveTrialStartDate(now)
            defaults.set(now.timeIntervalSince1970, forKey: trialStartPrefKey)
        }
        
        self.trialStartDate = startDate
        
        let lastKnown = defaults.double(forKey: lastKnownTimePrefKey)
        if lastKnown > 0 && now.timeIntervalSince1970 < (lastKnown - 3600) {
            self.trialDaysRemaining = 0
            self.isTrialActive = false
            self.isTrialExpired = true
            return
        }
        defaults.set(now.timeIntervalSince1970, forKey: lastKnownTimePrefKey)
        
        let trialDurationSeconds: TimeInterval = Double(Self.trialTotalDays) * 86400.0
        let elapsed = now.timeIntervalSince(startDate!)
        let remaining = trialDurationSeconds - elapsed
        
        if remaining > 0 {
            self.trialDaysRemaining = max(1, Int(ceil(remaining / 86400.0)))
            self.isTrialActive = true
            self.isTrialExpired = false
        } else {
            self.trialDaysRemaining = 0
            self.isTrialActive = false
            self.isTrialExpired = true
        }
    }
    
    private func loadSavedLicense() {
        initTrialState()
        
        if defaults.object(forKey: promoStatusPrefKey) != nil {
            self.isPromotionalProActive = defaults.bool(forKey: promoStatusPrefKey)
        } else {
            self.isPromotionalProActive = false
        }
        
        if let key = defaults.string(forKey: licenseKeyPrefKey), !key.isEmpty, verifyKey(key) {
            setPersonalUnlockedState(key: key)
            return
        }
        
        if let key = KeychainHelper.loadLicenseKey(), !key.isEmpty, verifyKey(key) {
            defaults.set(key, forKey: licenseKeyPrefKey)
            defaults.set(true, forKey: licenseStatusPrefKey)
            setPersonalUnlockedState(key: key)
            return
        }
        
        self.activeLicenseKey = ""
        self.hasPersonalLicense = false
        updateProStatus()
    }
    
    private func setPersonalUnlockedState(key: String) {
        self.activeLicenseKey = key
        self.hasPersonalLicense = true
        self.isProUnlocked = true
        self.licenseTier = .proLifetime
        self.isTrialActive = false
    }
    
    public func updateProStatus() {
        if hasPersonalLicense {
            self.isProUnlocked = true
            self.licenseTier = .proLifetime
            self.isTrialActive = false
        } else if isPromotionalProActive {
            self.isProUnlocked = true
            self.licenseTier = .proLifetime
        } else if isTrialActive && trialDaysRemaining > 0 {
            self.isProUnlocked = true
            self.licenseTier = .trial
        } else {
            self.isProUnlocked = false
            self.licenseTier = .free
        }
    }
    
    @MainActor
    public func applyRemotePromoStatus(_ promoActive: Bool) {
        self.isPromotionalProActive = promoActive
        self.defaults.set(promoActive, forKey: self.promoStatusPrefKey)
        self.updateProStatus()
    }
    
    @MainActor
    public func applyHwidProGrant(key: String, durationTitle: String?, expiresAt: String?) {
        self.activeLicenseKey = key
        self.hasPersonalLicense = true
        self.isProUnlocked = true
        self.licenseTier = .proLifetime
        self.hwidGrantTitle = durationTitle
        self.hwidGrantExpiresAt = expiresAt
        self.defaults.set(key, forKey: self.licenseKeyPrefKey)
        self.defaults.set(true, forKey: self.licenseStatusPrefKey)
    }
    
    public func syncRemotePromoStatus() async {
        guard let url = URL(string: "\(Self.serverBaseURL)/api/ihya/version.json") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let promoActive = json["promo_pro_active"] as? Bool ?? false
                await MainActor.run {
                    self.applyRemotePromoStatus(promoActive)
                }
            }
        } catch {}
    }
    
    public func activate(key: String) async -> (success: Bool, message: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard verifyKey(trimmed) else {
            return (false, "Geçersiz İhyâ Pro lisans anahtarı.")
        }
        
        defaults.set(trimmed, forKey: licenseKeyPrefKey)
        defaults.set(true, forKey: licenseStatusPrefKey)
        KeychainHelper.saveLicenseKey(trimmed)
        
        await MainActor.run {
            self.setPersonalUnlockedState(key: trimmed)
        }
        return (true, "İhyâ Pro başarıyla etkinleştirildi.")
    }
    
    public func autoRestoreHardwareLicense() async {
        let hwid = HardwareFingerprint.machineId
        guard let url = URL(string: "\(Self.serverBaseURL)/api/ihya/check-hwid.php?hwid=\(hwid)") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let registered = json["registered"] as? Bool, registered {
            
            let restoredKey = json["key"] as? String ?? ""
            let durationTitle = json["durationTitle"] as? String
            let expiresAt = json["expiresAt"] as? String
            
            await MainActor.run {
                self.applyHwidProGrant(
                    key: restoredKey.isEmpty ? "HWID-PRO-\(hwid.prefix(8))" : restoredKey,
                    durationTitle: durationTitle,
                    expiresAt: expiresAt
                )
            }
        }
    }
    
    public func verifyKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-").map(String.init)
        guard parts.count >= 4, parts[0] == "IHYA", parts[1] == "PRO" else {
            return false
        }
        let payload = parts[2]
        let providedSig = parts[3]
        let expectedSig = computeSignature(for: payload)
        return providedSig == expectedSig
    }
    
    public func computeSignature(for payload: String) -> String {
        let message = "\(payload):\(Self.masterSalt)"
        guard let keyData = Self.masterSalt.data(using: .utf8),
              let msgData = message.data(using: .utf8) else {
            return ""
        }
        
        var mac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            msgData.withUnsafeBytes { msgBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, keyData.count, msgBytes.baseAddress, msgData.count, &mac)
            }
        }
        return mac.prefix(8).map { String(format: "%02X", $0) }.joined()
    }
}
