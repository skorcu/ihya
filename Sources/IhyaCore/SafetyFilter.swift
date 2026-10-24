import Foundation

public final class SafetyFilter: Sendable {
    public static let shared = SafetyFilter()
    
    // Asla dokunulmayacak mutlak sistem yolları (SIP & Core OS)
    private let protectedSystemPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/Library",
        "/private/var/db",
        "/private/etc"
    ]
    
    // Kullanıcının şahsi kök veri alanları (Sistem temizleyicisi tarafından asla taranamayan ve silinemeyen alanlar)
    private let protectedUserDirectories: [String] = [
        "Documents",
        "Desktop",
        "Pictures",
        "Music",
        "Movies",
        "Creative Cloud Files",
        ".ssh",
        ".gnupg",
        ".aws",
        "Library/Keychains",
        "Library/Mail",
        "Library/Messages",
        "Library/Safari/Bookmarks.plist",
        "Library/Photos",
        "Library/Mobile Documents" // iCloud Drive
    ]
    
    public init() {}
    
    // MARK: - 1. Otomatik Sistem Arınması İçin Güvenlik Kontrolü
    /// Arka plan ve genel temizleme motorunun (CleanerEngine) asla kişisel klasörlere veya sistem çekirdeğine dokunmamasını garanti eder.
    public func isSafeToDelete(path: String) -> Bool {
        let cleanPath = (path as NSString).standardizingPath
        
        // 1. Kök dizin veya boş kontrolü
        guard !cleanPath.isEmpty, cleanPath != "/" else {
            return false
        }
        
        // 2. /Volumes kökü veya harici disk mount noktasının kendisi silinemez
        if cleanPath == "/Volumes" {
            return false
        }
        
        // 3. Sistem SIP kontrolü
        for sysPrefix in protectedSystemPrefixes {
            if cleanPath == sysPrefix || cleanPath.hasPrefix(sysPrefix + "/") {
                return false
            }
        }
        
        // 4. /Volumes altındaki sistem kopyaları kontrolü (Örn: /Volumes/Macintosh HD/System)
        if cleanPath.hasPrefix("/Volumes/") {
            let components = cleanPath.split(separator: "/")
            // /Volumes/DiskAdı -> Mount noktasının kendisi
            if components.count <= 2 {
                return false
            }
            // /Volumes/DiskAdı/System gibi sistem dizinleri
            if components.count >= 3 {
                let third = String(components[2])
                if ["System", "usr", "bin", "sbin", "private"].contains(third) {
                    return false
                }
            }
        }
        
        // 5. Kullanıcı kişisel klasör kontrolü
        let home = NSHomeDirectory()
        guard cleanPath != home else {
            return false
        }
        for userDir in protectedUserDirectories {
            let forbidden = (home as NSString).appendingPathComponent(userDir)
            if cleanPath == forbidden || cleanPath.hasPrefix(forbidden + "/") {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - 2. Kullanıcı Tercihli Dosya Yönetimi İçin Güvenlik Kontrolü (Space Lens, Çift Dosyalar, Büyük Dosyalar)
    /// Kullanıcının kendi seçtiği çift dosyaları veya eski büyük dosyaları Çöp Sepetine güvenle taşımasını sağlar.
    /// Sistem çekirdeği, ana kök klasörler ve ev dizini kesinlikle korunur, ancak altındaki münferit dosyalar silinebilir.
    public func isSafeForUserTrash(path: String) -> Bool {
        let cleanPath = (path as NSString).standardizingPath
        
        // 1. Kök dizin veya boş kontrolü
        guard !cleanPath.isEmpty, cleanPath != "/" else {
            return false
        }
        
        // 2. /Volumes kökü silinemez
        if cleanPath == "/Volumes" {
            return false
        }
        
        // 3. Sistem SIP ve macOS çekirdek yolları
        for sysPrefix in protectedSystemPrefixes {
            if cleanPath == sysPrefix || cleanPath.hasPrefix(sysPrefix + "/") {
                return false
            }
        }
        
        // 4. /Volumes altındaki sistem dizinleri veya disk kökleri
        if cleanPath.hasPrefix("/Volumes/") {
            let components = cleanPath.split(separator: "/")
            // /Volumes/DiskAdı kökü bizzat silinemez (Mount noktası korunur)
            if components.count <= 2 {
                return false
            }
            if components.count >= 3 {
                let third = String(components[2])
                if ["System", "usr", "bin", "sbin", "private"].contains(third) {
                    return false
                }
            }
        }
        
        // 5. Kullanıcı ev dizininin kendisi ASLA silinemez
        let home = NSHomeDirectory()
        guard cleanPath != home else {
            return false
        }
        
        // 6. Kişisel ana kök klasörlerin KENDİLERİ (Documents, Desktop, .ssh vb.) silinemez, içindeki tekil dosyalar silinebilir
        for userDir in protectedUserDirectories {
            let forbiddenRoot = (home as NSString).appendingPathComponent(userDir)
            if cleanPath == forbiddenRoot {
                return false
            }
        }
        
        // 7. Kritik anahtarlık ve bulut kütüphanesi kökleri kesin koruma
        let criticalRoots = [
            (home as NSString).appendingPathComponent("Library/Keychains"),
            (home as NSString).appendingPathComponent("Library/Mail"),
            (home as NSString).appendingPathComponent("Library/Messages"),
            (home as NSString).appendingPathComponent(".ssh"),
            (home as NSString).appendingPathComponent(".gnupg"),
            (home as NSString).appendingPathComponent(".aws")
        ]
        for crit in criticalRoots {
            if cleanPath == crit || cleanPath.hasPrefix(crit + "/") {
                return false
            }
        }
        
        return true
    }
}
