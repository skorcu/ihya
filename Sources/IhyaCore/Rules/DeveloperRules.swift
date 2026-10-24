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
        
        return items
    }
}
