import Foundation

public final class DeepSystemJunkScanner: Sendable {
    public static let shared = DeepSystemJunkScanner()
    
    public init() {}
    
    /// Telefon yedekleri, güncelleme atıkları, eski .dmg/.pkg kurulum dosyaları ve posta eklerini tarar
    public func scanDeepJunk() async -> [CleanItem] {
        var items: [CleanItem] = []
        let home = NSHomeDirectory()
        let fm = FileManager.default
        
        // 1. Telefon ve iPad Cihaz Yedekleri (~/Library/Application Support/MobileSync/Backup)
        let mobileSyncPath = (home as NSString).appendingPathComponent("Library/Application Support/MobileSync/Backup")
        if fm.fileExists(atPath: mobileSyncPath) {
            if let backups = try? fm.contentsOfDirectory(atPath: mobileSyncPath) {
                for backupFolder in backups {
                    let bPath = (mobileSyncPath as NSString).appendingPathComponent(backupFolder)
                    let sz = FastScanner.shared.getPathSize(path: bPath)
                    if sz > 50_000_000 { // 50 MB üzeri
                        items.append(CleanItem(
                            name: "iOS Cihaz Yedeği (\(backupFolder.prefix(8))...)",
                            path: bPath,
                            size: sz,
                            category: .systemJunk,
                            safety: .caution,
                            itemDescription: "Bilgisayara yedeklenmiş iPhone/iPad yerel cihaz yedeği."
                        ))
                    }
                }
            }
        }
        
        // 2. Eski iOS IPSW Güncelleme Dosyaları (~/Library/iTunes/* Software Updates)
        let itunesUpdatePaths = [
            (home as NSString).appendingPathComponent("Library/iTunes/iPhone Software Updates"),
            (home as NSString).appendingPathComponent("Library/iTunes/iPad Software Updates"),
            (home as NSString).appendingPathComponent("Library/iTunes/iPod Software Updates")
        ]
        for uPath in itunesUpdatePaths {
            if fm.fileExists(atPath: uPath) {
                if let files = try? fm.contentsOfDirectory(atPath: uPath) {
                    for f in files where f.hasSuffix(".ipsw") {
                        let fp = (uPath as NSString).appendingPathComponent(f)
                        let sz = FastScanner.shared.getPathSize(path: fp)
                        if sz > 10_000_000 {
                            items.append(CleanItem(
                                name: "iOS Yazılım Güncelleme Paketi (\(f))",
                                path: fp,
                                size: sz,
                                category: .systemJunk,
                                safety: .safe,
                                itemDescription: "Eski indirilmiş iOS yazılım geri yükleme paketi (.ipsw)."
                            ))
                        }
                    }
                }
            }
        }
        
        // 3. Xcode Simulator ve DeviceSupport Atıkları
        let devSupportPaths = [
            ((home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), "Xcode iOS Cihaz Sembolleri"),
            ((home as NSString).appendingPathComponent("Library/Developer/CoreSimulator/Caches"), "Xcode Simülatör Önbelleği"),
            ((home as NSString).appendingPathComponent("Library/Caches/com.apple.dt.XCTest"), "XCTest Geçici Dosyaları")
        ]
        for (dPath, label) in devSupportPaths {
            if fm.fileExists(atPath: dPath) {
                let sz = FastScanner.shared.getPathSize(path: dPath)
                if sz > 20_000_000 { // 20 MB üzeri
                    items.append(CleanItem(
                        name: label,
                        path: dPath,
                        size: sz,
                        category: .systemJunk,
                        safety: .safe,
                        itemDescription: "Geliştirici simülatör ve eski cihaz sembol kalıntıları."
                    ))
                }
            }
        }
        
        // 4. macOS Sistem Güncelleme Artıkları (/Library/Updates ve ~/Library/Caches/com.apple.SoftwareUpdate)
        let sysUpdatePaths = [
            "/Library/Updates",
            (home as NSString).appendingPathComponent("Library/Caches/com.apple.SoftwareUpdate")
        ]
        for sPath in sysUpdatePaths {
            if fm.fileExists(atPath: sPath) {
                let sz = FastScanner.shared.getPathSize(path: sPath)
                if sz > 5_000_000 {
                    items.append(CleanItem(
                        name: "macOS Güncelleme İndirme Kalıntıları",
                        path: sPath,
                        size: sz,
                        category: .systemJunk,
                        safety: .safe,
                        itemDescription: "Tamamlanmış veya eski sistem güncellemelerinden kalan geçici paketler."
                    ))
                }
            }
        }
        
        // 5. Unutulmuş Kurulum Dosyaları (.dmg, .pkg, .iso) - İndirilenler & Masaüstü
        let installScanFolders = [
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Desktop")
        ]
        for folder in installScanFolders {
            guard let files = try? fm.contentsOfDirectory(atPath: folder) else { continue }
            for file in files {
                let lower = file.lowercased()
                if lower.hasSuffix(".dmg") || lower.hasSuffix(".pkg") || lower.hasSuffix(".iso") {
                    let fp = (folder as NSString).appendingPathComponent(file)
                    let sz = FastScanner.shared.getPathSize(path: fp)
                    if sz > 5_000_000 { // 5 MB üstü
                        items.append(CleanItem(
                            name: "Kurulum Dosyası: \(file)",
                            path: fp,
                            size: sz,
                            category: .systemJunk,
                            safety: .caution,
                            itemDescription: "Kullanıldıktan sonra unutulan disk kurulum paketi (.dmg / .pkg)."
                        ))
                    }
                }
            }
        }
        
        // 6. Apple Mail İndirilen Ekleri (~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads)
        let mailDownloads = (home as NSString).appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads")
        if fm.fileExists(atPath: mailDownloads) {
            let sz = FastScanner.shared.getPathSize(path: mailDownloads)
            if sz > 5_000_000 {
                items.append(CleanItem(
                    name: "Mail İndirilen Ekleri & Önizlemeleri",
                    path: mailDownloads,
                    size: sz,
                    category: .systemJunk,
                    safety: .safe,
                    itemDescription: "E-postalardan açılmış ve diskte unutulmuş geçici dosya ekleri."
                ))
            }
        }
        
        return items
    }
}
