import Foundation
import IOKit
import CommonCrypto

public struct HardwareFingerprint: Sendable {
    public static var serialNumber: String {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return "UNKNOWN-SERIAL" }
        defer { IOObjectRelease(platformExpert) }
        
        if let serial = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return serial.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "UNKNOWN-SERIAL"
    }
    
    public static var hardwareUUID: String {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return "UNKNOWN-UUID" }
        defer { IOObjectRelease(platformExpert) }
        
        if let uuid = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return uuid.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "UNKNOWN-UUID"
    }
    
    public static var machineId: String {
        let raw = "\(serialNumber):\(hardwareUUID)"
        guard let data = raw.data(using: .utf8) else { return "HWID-FALLBACK" }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }
        
        let hex = digest.prefix(8).map { String(format: "%02X", $0) }.joined()
        return "HWID-\(hex)"
    }
}
