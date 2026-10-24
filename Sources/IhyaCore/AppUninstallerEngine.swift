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
        isSelected: Bool = false
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
        isSelected: Bool = false
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
    
    // Yalnızca macOS çekirdek (SIP / SSV) kök korumalı ve kullanıcı tarafından silinemeyen sistem uygulamaları
    private let nonDeletableAppleBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.apple.finder",
        "com.apple.systempreferences",
        "com.apple.AppStore",
        "com.apple.Preview",
        "com.apple.mail",
        "com.apple.MobileSMS",
        "com.apple.Photos",
        "com.apple.Music",
        "com.apple.podcasts",
        "com.apple.TV",
        "com.apple.Notes",
        "com.apple.reminders",
        "com.apple.iCal",
        "com.apple.AddressBook",
        "com.apple.FaceTime",
        "com.apple.shortcuts",
        "com.apple.weather",
        "com.apple.news",
        "com.apple.stocks",
        "com.apple.calculator",
        "com.apple.clock",
        "com.apple.Maps",
        "com.apple.TextEdit"
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
                    let appURL = URL(fileURLWithPath: appPath)
                    
                    var bundleId = ""
                    var appVersion = "1.0"
                    var displayName = rawName
                    
                    // 1. Resmi Apple Bundle API'si (Hem macOS hem iOS/iPadOS Wrapper paketlerini çözer)
                    if let bundle = Bundle(url: appURL) {
                        bundleId = bundle.bundleIdentifier ?? ""
                        if let ver = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
                            appVersion = ver
                        } else if let ver = bundle.infoDictionary?["CFBundleVersion"] as? String {
                            appVersion = ver
                        }
                        if let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String {
                            displayName = name
                        } else if let name = bundle.infoDictionary?["CFBundleName"] as? String {
                            displayName = name
                        }
                    }
                    
                    // 2. Yedek: Contents/Info.plist okuma
                    if bundleId.isEmpty {
                        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
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
                    }
                    
                    // 3. Yedek: iOS Wrapper/App.app/Info.plist
                    if bundleId.isEmpty {
                        let wrapperPlist = (appPath as NSString).appendingPathComponent("Wrapper/App.app/Info.plist")
                        if let dict = NSDictionary(contentsOfFile: wrapperPlist) {
                            bundleId = (dict["CFBundleIdentifier"] as? String) ?? ""
                            if let ver = dict["CFBundleShortVersionString"] as? String {
                                appVersion = ver
                            }
                            if let name = dict["CFBundleDisplayName"] as? String {
                                displayName = name
                            }
                        }
                    }
                    
                    if bundleId.isEmpty {
                        bundleId = "com.unknown.\(rawName.lowercased())"
                    }
                    
                    knownSignatures.insert(rawName.lowercased())
                    knownSignatures.insert(displayName.lowercased())
                    knownSignatures.insert(bundleId.lowercased())
                    
                    let isSystem = appPath.hasPrefix("/System") ||
                                   appPath == "/Applications/Safari.app" ||
                                   self.nonDeletableAppleBundleIds.contains(bundleId)
                    
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
    
    /// Bir uygulamaya ait derin kalıntıları tespit eder (360 Derece Sistem Taraması)
    private func findRemnants(forAppName appName: String, bundleId: String) -> [AppRemnantItem] {
        var remnants: [AppRemnantItem] = []
        let home = NSHomeDirectory()
        let lowerName = appName.lowercased()
        let lowerBundle = bundleId.lowercased()
        
        // Bundle parçalarından belirleyici kök adı çıkar (Örn: com.sarkacadam.app -> sarkacadam)
        let bundleParts = lowerBundle.split(separator: ".").map(String.init)
        let domainKeyword = bundleParts.first(where: {
            $0.count >= 4 && !["com", "org", "net", "app", "macos", "apple", "desktop", "unknown"].contains($0)
        })
        
        let targets: [(dirPath: String, label: String)] = [
            ((home as NSString).appendingPathComponent("Library/Application Support"), "Application Support"),
            ((home as NSString).appendingPathComponent("Library/Application Scripts"), "Uygulama Betikleri (Scripts)"),
            ((home as NSString).appendingPathComponent("Library/Caches"), "Önbellek (Caches)"),
            ((home as NSString).appendingPathComponent("Library/Containers"), "Kapsayıcı (Containers)"),
            ((home as NSString).appendingPathComponent("Library/Group Containers"), "Grup Kapsayıcıları (Shared Data)"),
            ((home as NSString).appendingPathComponent("Library/Saved Application State"), "Kayıtlı Durumlar"),
            ((home as NSString).appendingPathComponent("Library/WebKit"), "WebKit Verileri"),
            ((home as NSString).appendingPathComponent("Library/Logs"), "Sistem Günlükleri"),
            ((home as NSString).appendingPathComponent("Library/HTTPStorages"), "Ağ Depolaması"),
            ((home as NSString).appendingPathComponent("Library/LaunchAgents"), "Kullanıcı Başlangıç Servisi"),
            ("/Library/Application Support", "Sistem Application Support"),
            ("/Library/LaunchAgents", "Sistem Başlangıç Servisi"),
            ("/Library/LaunchDaemons", "Sistem Arka Plan Servisi"),
            ("/Library/Audio", "Ses ve Enstrüman Deposu")
        ]
        
        for target in targets {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: target.dirPath) else { continue }
            
            for folderName in contents {
                let lowerFolder = folderName.lowercased()
                
                let isDirectMatch = lowerFolder == lowerBundle ||
                                    lowerFolder == lowerName ||
                                    lowerFolder.hasPrefix(lowerBundle) ||
                                    lowerFolder.contains(lowerBundle) ||
                                    (lowerName.count >= 4 && lowerFolder.hasPrefix(lowerName)) ||
                                    (domainKeyword != nil && lowerFolder.contains(domainKeyword!))
                
                // Doğrudan bu uygulamanın kendi kırıntısı değilse Apple kök sistem dosyalarını koru
                if !isDirectMatch {
                    if appleWhitelist.contains(where: { lowerFolder == $0 || lowerFolder.hasPrefix($0 + ".") }) {
                        continue
                    }
                }
                
                if isDirectMatch {
                    let itemPath = (target.dirPath as NSString).appendingPathComponent(folderName)
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
                let isMatch = lowerPlist.contains(lowerBundle) ||
                              (lowerName.count >= 4 && lowerPlist.contains(lowerName)) ||
                              (domainKeyword != nil && lowerPlist.contains(domainKeyword!))
                if isMatch {
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
            ("Library/Application Scripts", "Uygulama Betikleri"),
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
                            isSelected: false
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
                isSelected: false
            )
        }.sorted { $0.totalSize > $1.totalSize }
    }
    
    public struct AppTrashResult: Sendable {
        public let reclaimedSize: Int64
        public let trashedCount: Int
        public let failedPaths: [String]
        
        public init(reclaimedSize: Int64, trashedCount: Int, failedPaths: [String]) {
            self.reclaimedSize = reclaimedSize
            self.trashedCount = trashedCount
            self.failedPaths = failedPaths
        }
    }
    
    /// Güvenli ve doğrulamalı Çöp Sepeti'ne taşıma metodu:
    /// 1. Standart FileManager.default.trashItem dener.
    /// 2. Yetki engeli durumunda (örneğin /Applications içindeki root izinli uygulamalar),
    ///    macOS Finder üzerinden (delete POSIX file) dener. Finder bu aşamada kullanıcıdan Touch ID / Parola ister.
    /// 3. Dosyanın diskten gerçekten yok olduğunu fiziki olarak FileManager.default.fileExists ile teyit eder.
    public func trashItemSafely(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        // Zaten yoksa başarı say
        guard FileManager.default.fileExists(atPath: path) else {
            return true
        }
        
        // 1. Standart FileManager trashItem denemesi
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            if !FileManager.default.fileExists(atPath: path) {
                return true
            }
        } catch {
            // İzin hatası (Error 513) veya kısıtlı alan durumunda Finder rotasına geç
        }
        
        // 2. Finder AppleScript rotası (Yönetici yetkisi / Touch ID gerektiren sistem paketleri)
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\")
                              .replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = "tell application \"Finder\" to delete (POSIX file \"\(escapedPath)\")"
        if let script = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            _ = script.executeAndReturnError(&errorInfo)
        }
        
        // 3. Kesin varlık doğrulaması
        return !FileManager.default.fileExists(atPath: path)
    }
    
    /// Uygulama açıksa önce nazikçe (terminate), kapanmazsa zorla (forceTerminate + SIGKILL) kapatır
    public func closeAppIfRunning(bundleId: String, bundlePath: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            // İhyâ'nın kendisini asla kapatma
            if app.bundleIdentifier == Bundle.main.bundleIdentifier || app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                continue
            }
            
            if (app.bundleIdentifier != nil && app.bundleIdentifier == bundleId) ||
               (app.bundleURL != nil && app.bundleURL?.path == bundlePath) {
                app.terminate()
                usleep(300_000) // 300 ms bekle
                if !app.isTerminated {
                    app.forceTerminate()
                    kill(app.processIdentifier, SIGKILL)
                    usleep(150_000)
                }
            }
        }
    }
    
    /// Seçili uygulama ve kırıntılarını GÜVENLE Çöp Sepeti'ne taşır (Geri alınabilir)
    public func trashApp(app: InstalledAppItem, trashBundle: Bool) -> AppTrashResult {
        var reclaimed: Int64 = 0
        var count = 0
        var failed: [String] = []
        
        // Kaldırılacak uygulama çalışıyorsa önce temizce kapat
        if trashBundle && !app.isSystemApp && app.isSelected {
            closeAppIfRunning(bundleId: app.bundleId, bundlePath: app.bundlePath)
        }
        
        // 1. Kütüphane kırıntılarını çöpe taşı
        for remnant in app.remnants where remnant.isSelected {
            if trashItemSafely(atPath: remnant.path) {
                reclaimed += remnant.size
                count += 1
            } else {
                failed.append(remnant.path)
            }
        }
        
        // 2. Uygulama ikilisini (.app) çöpe taşı (Eğer sistem uygulaması değilse ve seçilmişse)
        if trashBundle && !app.isSystemApp && app.isSelected {
            if trashItemSafely(atPath: app.bundlePath) {
                reclaimed += app.appSize
                count += 1
            } else {
                failed.append(app.bundlePath)
            }
        }
        
        return AppTrashResult(reclaimedSize: reclaimed, trashedCount: count, failedPaths: failed)
    }
    
    /// Yetim kalıntı grubunu Çöp Sepeti'ne taşır
    public func trashOrphanGroup(group: OrphanedRemnantGroup) -> AppTrashResult {
        var reclaimed: Int64 = 0
        var count = 0
        var failed: [String] = []
        
        for item in group.items where item.isSelected {
            if trashItemSafely(atPath: item.path) {
                reclaimed += item.size
                count += 1
            } else {
                failed.append(item.path)
            }
        }
        return AppTrashResult(reclaimedSize: reclaimed, trashedCount: count, failedPaths: failed)
    }
}
