import Foundation

public final class DeveloperRules: Sendable {
    public static let shared = DeveloperRules()
    
    public init() {}
    
    public func scan() async -> [CleanItem] {
        var items: [CleanItem] = []
        let home = NSHomeDirectory()
        
        // 1. Xcode DerivedData (~/Library/Developer/Xcode/DerivedData)
        let derivedData = (home as NSString).appendingPathComponent("Library/Developer/Xcode/DerivedData")
        if FileManager.default.fileExists(atPath: derivedData) {
            let size = FastScanner.shared.getPathSize(path: derivedData)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "Xcode DerivedData",
                    path: derivedData,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Xcode derleme ara dosyaları ve dizin önbellekleri"
                ))
            }
        }
        
        // 2. Xcode Arşivleri (~/Library/Developer/Xcode/Archives)
        let archives = (home as NSString).appendingPathComponent("Library/Developer/Xcode/Archives")
        if FileManager.default.fileExists(atPath: archives) {
            let size = FastScanner.shared.getPathSize(path: archives)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "Xcode Eski Arşivler",
                    path: archives,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Eski derlenmiş proje arşivleri"
                ))
            }
        }
        
        // 3. Xcode iOS DeviceSupport
        let deviceSupport = (home as NSString).appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport")
        if FileManager.default.fileExists(atPath: deviceSupport) {
            let size = FastScanner.shared.getPathSize(path: deviceSupport)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "iOS Cihaz Sembolleri (DeviceSupport)",
                    path: deviceSupport,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Eski iOS sürümlerinin hata ayıklama sembolleri"
                ))
            }
        }
        
        // 4. Homebrew Cache (~/Library/Caches/Homebrew)
        let brewCache = (home as NSString).appendingPathComponent("Library/Caches/Homebrew")
        if FileManager.default.fileExists(atPath: brewCache) {
            let size = FastScanner.shared.getPathSize(path: brewCache)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "Homebrew İndirme Önbelleği",
                    path: brewCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "İndirilmiş eski Homebrew paket şişeleri (bottles)"
                ))
            }
        }
        
        // 5. Node / NPM Önbelleği (~/.npm)
        let npmCache = (home as NSString).appendingPathComponent(".npm")
        if FileManager.default.fileExists(atPath: npmCache) {
            let size = FastScanner.shared.getPathSize(path: npmCache)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "NPM Paket Önbelleği",
                    path: npmCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "İndirilmiş Node.js paket önbelleği"
                ))
            }
        }
        
        // 6. Yarn Önbelleği (~/Library/Caches/Yarn)
        let yarnCache = (home as NSString).appendingPathComponent("Library/Caches/Yarn")
        if FileManager.default.fileExists(atPath: yarnCache) {
            let size = FastScanner.shared.getPathSize(path: yarnCache)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "Yarn Paket Önbelleği",
                    path: yarnCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Yarn bağımlılık önbelleği"
                ))
            }
        }
        
        // 7. CocoaPods Önbelleği (~/Library/Caches/CocoaPods)
        let cocoapodsCache = (home as NSString).appendingPathComponent("Library/Caches/CocoaPods")
        if FileManager.default.fileExists(atPath: cocoapodsCache) {
            let size = FastScanner.shared.getPathSize(path: cocoapodsCache)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "CocoaPods Önbelleği",
                    path: cocoapodsCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "iOS/macOS CocoaPods kütüphane önbelleği"
                ))
            }
        }
        
        // 8. Gradle Önbelleği (~/.gradle/caches)
        let gradleCache = (home as NSString).appendingPathComponent(".gradle/caches")
        if FileManager.default.fileExists(atPath: gradleCache) {
            let size = FastScanner.shared.getPathSize(path: gradleCache)
            if size > 50_000_000 {
                items.append(CleanItem(
                    name: "Gradle & Android Önbelleği",
                    path: gradleCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Android Studio ve Gradle derleme artıkları"
                ))
            }
        }
        
        // 9. Python uv Paket & Derleme Önbelleği (~/.cache/uv)
        let uvCache = (home as NSString).appendingPathComponent(".cache/uv")
        if FileManager.default.fileExists(atPath: uvCache) {
            let size = FastScanner.shared.getPathSize(path: uvCache)
            if size > 10_000_000 {
                items.append(CleanItem(
                    name: "Python uv Önbelleği",
                    path: uvCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Hızlı Python paket yöneticisi (uv) indirme ve tekerlek (wheel) önbelleği"
                ))
            }
        }
        
        // 10. Puppeteer Başsız Tarayıcı İndirmeleri (~/.cache/puppeteer)
        let puppeteerCache = (home as NSString).appendingPathComponent(".cache/puppeteer")
        if FileManager.default.fileExists(atPath: puppeteerCache) {
            let size = FastScanner.shared.getPathSize(path: puppeteerCache)
            if size > 20_000_000 {
                items.append(CleanItem(
                    name: "Puppeteer Tarayıcı İndirmeleri",
                    path: puppeteerCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Otomasyon için indirilmiş eski Chromium sürümleri"
                ))
            }
        }
        
        // 11. PNPM Global Paket Deposu (~/.pnpm-store veya ~/Library/pnpm/store)
        let pnpmPaths = [
            (home as NSString).appendingPathComponent(".pnpm-store"),
            (home as NSString).appendingPathComponent("Library/pnpm/store")
        ]
        for pPath in pnpmPaths {
            if FileManager.default.fileExists(atPath: pPath) {
                let size = FastScanner.shared.getPathSize(path: pPath)
                if size > 50_000_000 {
                    items.append(CleanItem(
                        name: "PNPM Paket Deposu",
                        path: pPath,
                        size: size,
                        category: .developerVault,
                        safety: .developer,
                        itemDescription: "pnpm ile indirilmiş içerik adresli paket deposu"
                    ))
                    break
                }
            }
        }
        
        // 12. Rust Cargo Paket Önbelleği (~/.cargo/registry/cache)
        let cargoCache = (home as NSString).appendingPathComponent(".cargo/registry/cache")
        if FileManager.default.fileExists(atPath: cargoCache) {
            let size = FastScanner.shared.getPathSize(path: cargoCache)
            if size > 20_000_000 {
                items.append(CleanItem(
                    name: "Rust Cargo Crate Önbelleği",
                    path: cargoCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "İndirilmiş Rust sandık (crate) paket arşivleri"
                ))
            }
        }
        
        // 13. Bun Paket Önbelleği (~/.bun/install/cache)
        let bunCache = (home as NSString).appendingPathComponent(".bun/install/cache")
        if FileManager.default.fileExists(atPath: bunCache) {
            let size = FastScanner.shared.getPathSize(path: bunCache)
            if size > 20_000_000 {
                items.append(CleanItem(
                    name: "Bun Paket Önbelleği",
                    path: bunCache,
                    size: size,
                    category: .developerVault,
                    safety: .developer,
                    itemDescription: "Bun çalışma zamanı bağımlılık önbelleği"
                ))
            }
        }
        
        return items
    }
}
