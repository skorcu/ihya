import Foundation
import CryptoKit

/// Kullanıcıya hiçbir sistem anahtar zinciri (Keychain) onay penceresi çıkartmadan,
/// Mac'in donanım kimliğiyle şifrelenen yerel güvenli lisans kasası (AES-256 GCM).
public struct KeychainHelper: Sendable {
    private static let vaultFileName = ".ihya_vault.dat"
    
    private static var vaultURL: URL {
        let home = NSHomeDirectory()
        let appSupport = (home as NSString).appendingPathComponent("Library/Application Support/com.caneser.ihya")
        try? FileManager.default.createDirectory(atPath: appSupport, withIntermediateDirectories: true)
        return URL(fileURLWithPath: appSupport).appendingPathComponent(vaultFileName)
    }
    
    private static var encryptionKey: SymmetricKey {
        let rawKey = "IhyaSecureVault:" + HardwareFingerprint.machineId
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return SymmetricKey(data: digest)
    }
    
    private static func readVault() -> [String: String] {
        guard let data = try? Data(contentsOf: vaultURL),
              let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(sealedBox, using: encryptionKey),
              let dict = try? JSONSerialization.jsonObject(with: decrypted) as? [String: String] else {
            return [:]
        }
        return dict
    }
    
    private static func writeVault(_ dict: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let sealedBox = try? AES.GCM.seal(data, using: encryptionKey),
              let combined = sealedBox.combined else {
            return
        }
        try? combined.write(to: vaultURL, options: .atomic)
    }
    
    public static func saveLicenseKey(_ key: String) {
        var dict = readVault()
        dict["pro_license_key"] = key
        writeVault(dict)
    }
    
    public static func loadLicenseKey() -> String? {
        readVault()["pro_license_key"]
    }
    
    public static func deleteLicenseKey() {
        var dict = readVault()
        dict.removeValue(forKey: "pro_license_key")
        writeVault(dict)
    }
    
    public static func saveTrialStartDate(_ date: Date) {
        var dict = readVault()
        dict["trial_start_timestamp"] = String(date.timeIntervalSince1970)
        writeVault(dict)
    }
    
    public static func loadTrialStartDate() -> Date? {
        guard let str = readVault()["trial_start_timestamp"],
              let ts = Double(str) else {
            return nil
        }
        return Date(timeIntervalSince1970: ts)
    }
}
