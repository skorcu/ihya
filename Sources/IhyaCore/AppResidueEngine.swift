import Foundation

public final class AppResidueEngine: Sendable {
    public static let shared = AppResidueEngine()
    
    public init() {}
    
    /// Sistemde yüklü olan tüm uygulamaların Bundle ID ve adlarını toplar
    public func getInstalledAppSignatures() -> Set<String> {
        var signatures = Set<String>()
        let appDirs = [
            "/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
            "/System/Applications"
        ]
        
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = (dir as NSString).appendingPathComponent(item)
                let nameWithoutExtension = (item as NSString).deletingPathExtension.lowercased()
                signatures.insert(nameWithoutExtension)
                
                // Info.plist oku
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                if let dict = NSDictionary(contentsOfFile: plistPath) {
                    if let bundleId = dict["CFBundleIdentifier"] as? String {
                        signatures.insert(bundleId.lowercased())
                    }
                    if let bundleName = dict["CFBundleName"] as? String {
                        signatures.insert(bundleName.lowercased())
                    }
                }
            }
        }
        
        return signatures
    }
    
    /// Artık yüklü olmayan (yetim) uygulama artıklarını tarar
    public func scanOrphanResidues() async -> [CleanItem] {
        var residues: [CleanItem] = []
        let signatures = getInstalledAppSignatures()
        let home = NSHomeDirectory()
        
        let targetScanDirs = [
            ("Library/Application Support", CleanCategoryType.appResidues),
            ("Library/Caches", CleanCategoryType.appResidues),
            ("Library/Containers", CleanCategoryType.appResidues),
            ("Library/Saved Application State", CleanCategoryType.appResidues),
            ("Library/WebKit", CleanCategoryType.appResidues)
        ]
        
        // Apple'ın kendi dahili bileşenleri için koruma listesi
        let appleWhitelist: Set<String> = [
            "apple", "com.apple", "cloudkit", "addressbook", "callhistory",
            "fontcollections", "syncservices", "quicklook", "spotlight"
        ]
        
        for (subPath, category) in targetScanDirs {
            let fullTargetDir = (home as NSString).appendingPathComponent(subPath)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: fullTargetDir) else { continue }
            
            for folderName in contents {
                let lowerName = folderName.lowercased()
                
                // Apple sistem klasörlerini atla
                if appleWhitelist.contains(where: { lowerName.contains($0) }) {
                    continue
                }
                
                // Eğer bu klasör bilinen hiçbir yüklü uygulamayla eşleşmiyorsa -> Yetim artık!
                let matchesAnyApp = signatures.contains(where: { sig in
                    lowerName.contains(sig) || sig.contains(lowerName)
                })
                
                if !matchesAnyApp {
                    let orphanPath = (fullTargetDir as NSString).appendingPathComponent(folderName)
                    let size = FastScanner.shared.getPathSize(path: orphanPath)
                    
                    if size > 1_000_000 { // 1 MB üstü yetimler
                        residues.append(CleanItem(
                            name: folderName,
                            path: orphanPath,
                            size: size,
                            category: category,
                            safety: .caution,
                            itemDescription: "Silinmiş eski uygulamanın yetim kalıntısı"
                        ))
                    }
                }
            }
        }
        
        return residues
    }
}
