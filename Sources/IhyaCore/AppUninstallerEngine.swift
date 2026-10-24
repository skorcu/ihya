import Foundation
import AppKit

public struct AppRemnantItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let categoryName: String
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        size: Int64,
        categoryName: String,
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.categoryName = categoryName
        self.isSelected = isSelected
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct InstalledAppItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bundleId: String
    public let version: String
    public let bundlePath: String
    public let appSize: Int64
    public let isSystemApp: Bool
    public var remnants: [AppRemnantItem]
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        bundleId: String,
        version: String,
        bundlePath: String,
        appSize: Int64,
        isSystemApp: Bool,
        remnants: [AppRemnantItem] = [],
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.bundlePath = bundlePath
        self.appSize = appSize
        self.isSystemApp = isSystemApp
        self.remnants = remnants
        self.isSelected = isSelected
    }
    
    public var totalFootprint: Int64 {
        appSize + remnants.reduce(0) { $0 + $1.size }
    }
    
    public var selectedReclaimableSize: Int64 {
        let appPart = (isSelected && !isSystemApp) ? appSize : 0
        let remnantPart = remnants.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        return appPart + remnantPart
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalFootprint, countStyle: .file)
    }
}

public struct OrphanedRemnantGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let signature: String
    public var items: [AppRemnantItem]
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        signature: String,
        items: [AppRemnantItem],
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.signature = signature
        self.items = items
        self.isSelected = isSelected
    }
    
    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

public final class AppUninstallerEngine: Sendable {
    public static let shared = AppUninstallerEngine()
    
    public init() {}
    
    private let appleWhitelist: Set<String> = [
        "apple", "com.apple", "cloudkit", "addressbook", "callhistory",
        "fontcollections", "syncservices", "quicklook", "spotlight",
        "keychains", "safari", "finder", "systempreferences", "dock",
        "screentime", "photos", "mail", "messages", "music", "podcasts",
        "tv", "appstore", "maps", "shortcuts", "weather", "news", "notes",
        "reminders", "calendar", "contacts", "facetime", "preview"
    ]
    
    /// Yüklü uygulamaları ve sistemdeki tüm derin kırıntılarını tarar
    public func scanInstalledApps() async -> (apps: [InstalledAppItem], orphans: [OrphanedRemnantGroup]) {
        return await Task.detached(priority: .userInitiated) {
            let scanDirs = [
                "/Applications",
                (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
            ]
            
            var discoveredApps: [InstalledAppItem] = []
            var knownSignatures = Set<String>()
            
            for dir in scanDirs {
                guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
                for item in contents where item.hasSuffix(".app") {
                    let appPath = (dir as NSString).appendingPathComponent(item)
                    let rawName = (item as NSString).deletingPathExtension
                    
                    let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                    var bundleId = ""
                    var appVersion = "1.0"
                    var displayName = rawName
                    
                    if let dict = NSDictionary(contentsOfFile: plistPath) {
                        bundleId = (dict["CFBundleIdentifier"] as? String) ?? ""
                        if let ver = dict["CFBundleShortVersionString"] as? String {
                            appVersion = ver
                        } else if let ver = dict["CFBundleVersion"] as? String {
                            appVersion = ver
                        }
                        if let name = dict["CFBundleDisplayName"] as? String {
                            displayName = name
                        } else if let name = dict["CFBundleName"] as? String {
                            displayName = name
                        }
                    }
                    
                    if bundleId.isEmpty {
                        bundleId = "com.unknown.\(rawName.lowercased())"
                    }
                    
                    knownSignatures.insert(rawName.lowercased())
                    knownSignatures.insert(displayName.lowercased())
                    knownSignatures.insert(bundleId.lowercased())
                    
                    let isSystem = appPath.hasPrefix("/System") ||
                                   bundleId.hasPrefix("com.apple.") ||
                                   appPath == "/Applications/Safari.app"
                    
                    let appSize = FastScanner.shared.getPathSize(path: appPath)
                    
                    // Uygulamanın derin kütüphane kırıntılarını ara
                    let remnants = self.findRemnants(forAppName: rawName, bundleId: bundleId)
                    
                    let appItem = InstalledAppItem(
                        name: displayName,
                        bundleId: bundleId,
                        version: appVersion,
                        bundlePath: appPath,
                        appSize: appSize,
                        isSystemApp: isSystem,
                        remnants: remnants,
                        isSelected: false
                    )
                    discoveredApps.append(appItem)
                }
            }
            
            // Boyuta göre en büyük uygulamalar en üstte
            discoveredApps.sort { $0.totalFootprint > $1.totalFootprint }
            
            // Yetim kalıntıları (Orphaned Leftovers) tara
            let orphans = self.findOrphanedRemnants(knownSignatures: knownSignatures)
            
            return (discoveredApps, orphans)
        }.value
    }
    
    /// Bir uygulamaya ait derin kalıntıları tespit eder
    private func findRemnants(forAppName appName: String, bundleId: String) -> [AppRemnantItem] {
        var remnants: [AppRemnantItem] = []
        let home = NSHomeDirectory()
        let lowerName = appName.lowercased()
        let lowerBundle = bundleId.lowercased()
        
        let targets: [(subPath: String, label: String, isFolderDirectMatch: Bool)] = [
            ("Library/Application Support", "Application Support", true),
            ("Library/Caches", "Önbellek (Caches)", true),
            ("Library/Containers", "Kapsayıcı (Containers)", true),
            ("Library/Saved Application State", "Kayıtlı Durumlar", true),
            ("Library/WebKit", "WebKit Verileri", true),
            ("Library/Logs", "Sistem Günlükleri", true),
            ("Library/HTTPStorages", "Ağ Depolaması", true)
        ]
        
        for target in targets {
            let fullTargetDir = (home as NSString).appendingPathComponent(target.subPath)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: fullTargetDir) else { continue }
            
            for folderName in contents {
                let lowerFolder = folderName.lowercased()
                
                // Apple sistem dosyalarını atla
                if appleWhitelist.contains(where: { lowerFolder == $0 || lowerFolder.hasPrefix($0 + ".") }) {
                    continue
                }
                
                let isMatch = lowerFolder == lowerBundle ||
                              lowerFolder == lowerName ||
                              lowerFolder.hasPrefix(lowerBundle) ||
                              lowerFolder.contains(lowerBundle) ||
                              (lowerName.count >= 4 && lowerFolder.hasPrefix(lowerName))
                
                if isMatch {
                    let itemPath = (fullTargetDir as NSString).appendingPathComponent(folderName)
                    let size = FastScanner.shared.getPathSize(path: itemPath)
                    if size > 0 {
                        remnants.append(AppRemnantItem(
                            name: folderName,
                            path: itemPath,
                            size: size,
                            categoryName: target.label,
                            isSelected: true
                        ))
                    }
                }
            }
        }
        
        // Preferences (.plist) kontrolü
        let prefsDir = (home as NSString).appendingPathComponent("Library/Preferences")
        if let plistContents = try? FileManager.default.contentsOfDirectory(atPath: prefsDir) {
            for plistName in plistContents where plistName.hasSuffix(".plist") {
                let lowerPlist = plistName.lowercased()
                if lowerPlist.contains(lowerBundle) || (lowerName.count >= 4 && lowerPlist.contains(lowerName)) {
                    let plistPath = (prefsDir as NSString).appendingPathComponent(plistName)
                    let size = FastScanner.shared.getPathSize(path: plistPath)
                    remnants.append(AppRemnantItem(
                        name: plistName,
                        path: plistPath,
                        size: max(size, 1024),
                        categoryName: "Tercihler (Preferences)",
                        isSelected: true
                    ))
                }
            }
        }
        
        return remnants.sorted { $0.size > $1.size }
    }
    
    /// Daha önce silinmiş uygulamaların yetim kalıntılarını toplar
    private func findOrphanedRemnants(knownSignatures: Set<String>) -> [OrphanedRemnantGroup] {
        var groups: [String: [AppRemnantItem]] = [:]
        let home = NSHomeDirectory()
        
        let targetDirs = [
            ("Library/Application Support", "Application Support"),
            ("Library/Caches", "Önbellek"),
            ("Library/Containers", "Kapsayıcı"),
            ("Library/Saved Application State", "Kayıtlı Durum")
        ]
        
        for (subPath, label) in targetDirs {
            let fullDir = (home as NSString).appendingPathComponent(subPath)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: fullDir) else { continue }
            
            for folder in contents {
                let lower = folder.lowercased()
                if appleWhitelist.contains(where: { lower.contains($0) }) { continue }
                
                // Eğer bilinen hiçbir yüklü uygulamayla eşleşmiyorsa
                let matchesInstalled = knownSignatures.contains(where: { sig in
                    lower == sig || lower.hasPrefix(sig) || sig.hasPrefix(lower)
                })
                
                if !matchesInstalled {
                    let path = (fullDir as NSString).appendingPathComponent(folder)
                    let size = FastScanner.shared.getPathSize(path: path)
                    
                    if size > 500_000 { // 500 KB üstü yetimler
                        let baseKey = (folder as NSString).deletingPathExtension
                        let item = AppRemnantItem(
                            name: folder,
                            path: path,
                            size: size,
                            categoryName: label,
                            isSelected: true
                        )
                        groups[baseKey, default: []].append(item)
                    }
                }
            }
        }
        
        return groups.map { key, items in
            OrphanedRemnantGroup(
                name: key,
                signature: key,
                items: items,
                isSelected: true
            )
        }.sorted { $0.totalSize > $1.totalSize }
    }
    
    /// Seçili uygulama ve kırıntılarını GÜVENLE Çöp Sepeti'ne taşır (Geri alınabilir)
    public func trashApp(app: InstalledAppItem, trashBundle: Bool) -> (reclaimedSize: Int64, trashedCount: Int) {
        var reclaimed: Int64 = 0
        var count = 0
        
        // 1. Kütüphane kırıntılarını çöpe taşı
        for remnant in app.remnants where remnant.isSelected {
            let url = URL(fileURLWithPath: remnant.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                reclaimed += remnant.size
                count += 1
            } catch {
                // Hata durumunda sessizce devam et
            }
        }
        
        // 2. Uygulama ikilisini (.app) çöpe taşı (Eğer sistem uygulaması değilse ve seçilmişse)
        if trashBundle && !app.isSystemApp && app.isSelected {
            let appURL = URL(fileURLWithPath: app.bundlePath)
            do {
                try FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
                reclaimed += app.appSize
                count += 1
            } catch {
                // Hata
            }
        }
        
        return (reclaimed, count)
    }
    
    /// Yetim kalıntı grubunu Çöp Sepeti'ne taşır
    public func trashOrphanGroup(group: OrphanedRemnantGroup) -> Int64 {
        var reclaimed: Int64 = 0
        for item in group.items where item.isSelected {
            let url = URL(fileURLWithPath: item.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                reclaimed += item.size
            } catch {}
        }
        return reclaimed
    }
}
