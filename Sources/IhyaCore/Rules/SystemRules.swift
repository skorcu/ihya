import Foundation

public final class SystemRules: Sendable {
    public static let shared = SystemRules()
    
    public init() {}
    
    public func scan() async -> [CleanItem] {
        var items: [CleanItem] = []
        let home = NSHomeDirectory()
        
        // 1. Kullanıcı Önbellekleri (~/Library/Caches)
        let userCachesPath = (home as NSString).appendingPathComponent("Library/Caches")
        if FileManager.default.fileExists(atPath: userCachesPath) {
            if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: userCachesPath) {
                for sub in subdirs {
                    // Sistem ve iCloud kritik klasörlerini atla
                    if sub.hasPrefix("com.apple.bird") || sub.hasPrefix("CloudKit") { continue }
                    let fullPath = (userCachesPath as NSString).appendingPathComponent(sub)
                    let size = FastScanner.shared.getPathSize(path: fullPath)
                    if size > 1_000_000 { // 1 MB'dan büyük olanlar
                        items.append(CleanItem(
                            name: sub,
                            path: fullPath,
                            size: size,
                            category: .systemJunk,
                            safety: .safe,
                            itemDescription: "Kullanıcı uygulama önbelleği"
                        ))
                    }
                }
            }
        }
        
        // 2. Sistem Günlükleri (~/Library/Logs)
        let userLogsPath = (home as NSString).appendingPathComponent("Library/Logs")
        if FileManager.default.fileExists(atPath: userLogsPath) {
            let size = FastScanner.shared.getPathSize(path: userLogsPath)
            if size > 100_000 {
                items.append(CleanItem(
                    name: "Kullanıcı Günlükleri (Logs)",
                    path: userLogsPath,
                    size: size,
                    category: .systemJunk,
                    safety: .safe,
                    itemDescription: "Eski uygulama hata ve çalışma kayıtları"
                ))
            }
        }
        
        // 3. Tanı ve Çökme Raporları
        let diagReportsPath = (home as NSString).appendingPathComponent("Library/Logs/DiagnosticReports")
        if FileManager.default.fileExists(atPath: diagReportsPath) {
            let size = FastScanner.shared.getPathSize(path: diagReportsPath)
            if size > 50_000 {
                items.append(CleanItem(
                    name: "Çökme & Tanı Raporları",
                    path: diagReportsPath,
                    size: size,
                    category: .systemJunk,
                    safety: .safe,
                    itemDescription: "macOS ve uygulama çökme günlükleri"
                ))
            }
        }
        
        // 4. QuickLook Küçük Resim Önbelleği
        let qlCache = "/private/var/folders"
        if FileManager.default.fileExists(atPath: qlCache) {
            // QuickLook cache boyutu tahmin edilebilir veya temizleme emri verilebilir
        }
        
        return items
    }
    
    public func flushDNS() {
        let task = Process()
        task.launchPath = "/usr/bin/dscacheutil"
        task.arguments = ["-flushcache"]
        try? task.run()
        task.waitUntilExit()
    }
}
