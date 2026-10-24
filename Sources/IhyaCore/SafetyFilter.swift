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
        "/private/etc",
        "/Volumes"
    ]
    
    // Kullanıcının şahsi veri alanları (Asla sistem temizleyicisi tarafından silinemez)
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
    
    public func isSafeToDelete(path: String) -> Bool {
        let cleanPath = (path as NSString).standardizingPath
        
        // 1. Kök dizin veya boş kontrolü
        guard !cleanPath.isEmpty, cleanPath != "/" else {
            return false
        }
        
        // 2. Sistem SIP kontrolü
        for sysPrefix in protectedSystemPrefixes {
            if cleanPath == sysPrefix || cleanPath.hasPrefix(sysPrefix + "/") {
                return false
            }
        }
        
        // 3. Kullanıcı kişisel klasör kontrolü
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
}
