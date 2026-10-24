import Foundation
import AppKit

public final class TelemetryManager: @unchecked Sendable {
    public static let shared = TelemetryManager()
    
    private let telemetryURL = URL(string: "https://caneser.com/api/ihya/telemetry.php")
    private let lastPingKey = "ihya_last_telemetry_ping_time"
    
    private init() {}
    
    public func sendHeartbeat() {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self, let url = self.telemetryURL else { return }
            
            let hwid = HardwareFingerprint.machineId
            let macosVersion = ProcessInfo.processInfo.operatingSystemVersionString
            
            #if arch(arm64)
            let arch = "Apple Silicon (arm64)"
            #elseif arch(x86_64)
            let arch = "Intel (x86_64)"
            #else
            let arch = "Universal"
            #endif
            
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.2"
            let lic = LicenseManager.shared
            let hasPersonal = lic.hasPersonalLicense
            let isPro = lic.isProUnlocked
            let activeKey = lic.activeLicenseKey
            
            let payload: [String: Any] = [
                "hwid": hwid,
                "macosVersion": macosVersion,
                "arch": arch,
                "appVersion": appVersion,
                "hasPersonalLicense": hasPersonal,
                "isPro": isPro,
                "key": activeKey
            ]
            
            guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
            
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 5.0
            req.httpBody = bodyData
            
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let promoActive = json["promo_pro_active"] as? Bool {
                        await MainActor.run {
                            lic.applyRemotePromoStatus(promoActive)
                        }
                    }
                    
                    if let isHwidPro = json["isHwidPro"] as? Bool, isHwidPro {
                        let duration = json["hwidDuration"] as? String
                        let expires = json["hwidExpiresAt"] as? String
                        await MainActor.run {
                            lic.applyHwidProGrant(
                                key: lic.activeLicenseKey.isEmpty ? "HWID-PRO-\(hwid.prefix(8))" : lic.activeLicenseKey,
                                durationTitle: duration,
                                expiresAt: expires
                            )
                        }
                    }
                    
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastPingKey)
                }
            } catch {
                // Silently ignore if offline
            }
        }
    }
}
