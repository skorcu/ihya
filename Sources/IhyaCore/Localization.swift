import Foundation

public enum Language: String, CaseIterable, Identifiable, Sendable {
    case turkish = "tr"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
}

public final class Localization: ObservableObject, @unchecked Sendable {
    public static let shared = Localization()
    
    @Published public var currentLanguage: Language = .turkish
    
    private init() {
        let preferred = Locale.preferredLanguages.first ?? "tr"
        if preferred.hasPrefix("tr") {
            currentLanguage = .turkish
        } else {
            currentLanguage = .english
        }
    }
    
    public func text(for key: String) -> String {
        switch currentLanguage {
        case .turkish:
            return trStrings[key] ?? enStrings[key] ?? key
        case .english:
            return enStrings[key] ?? key
        }
    }
    
    private let trStrings: [String: String] = [
        "app_name": "İhyâ",
        "tagline": "Yeni Nesil macOS Arınma & Canlanma Motoru",
        "smart_clean": "Akıllı Arınma",
        "scan_now": "Sistemi Tara",
        "clean_now": "Arındır",
        "cleaning": "Arındırılıyor...",
        "scanning": "Taranıyor...",
        "ready": "Sistem Hazır",
        "space_reclaimable": "Kazanılabilir Alan",
        "system_junk": "Sistem Çöpleri",
        "app_residues": "Uygulama Artıkları",
        "developer_vault": "Geliştirici Kasası",
        "duplicate_files": "Çift Dosyalar",
        "ghost_daemons": "Hayalet Servisler",
        "app_lipo": "Mimari İnceltici",
        "trash_bins": "Çöp Kutuları",
        "pro_badge": "PRO",
        "pro_unlocked": "İhyâ Pro Aktif",
        "activate_pro": "Pro'ya Yükselt",
        "legal_title": "Yasal Uyarı ve Sorumluluk Reddi",
        "legal_accept": "Okudum, Anladım ve Kabul Ediyorum",
        "safe_badge": "Güvenli"
    ]
    
    private let enStrings: [String: String] = [
        "app_name": "Ihya",
        "tagline": "Next-Gen macOS Revitalization & Purification Engine",
        "smart_clean": "Smart Revive",
        "scan_now": "Scan System",
        "clean_now": "Purify",
        "cleaning": "Purifying...",
        "scanning": "Scanning...",
        "ready": "System Ready",
        "space_reclaimable": "Reclaimable Space",
        "system_junk": "System Junk",
        "app_residues": "App Residues",
        "developer_vault": "Developer Vault",
        "duplicate_files": "Duplicate Files",
        "ghost_daemons": "Ghost Daemons",
        "app_lipo": "App Architecture Slimmer",
        "trash_bins": "Trash Bins",
        "pro_badge": "PRO",
        "pro_unlocked": "Ihya Pro Active",
        "activate_pro": "Upgrade to Pro",
        "legal_title": "Legal Notice & Liability Disclaimer",
        "legal_accept": "I Have Read, Understood & Agree",
        "safe_badge": "Safe"
    ]
}
