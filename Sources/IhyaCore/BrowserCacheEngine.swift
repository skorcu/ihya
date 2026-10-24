import Foundation
import AppKit

/// Tarayıcı veri alt kategorileri
public enum BrowserDataType: String, CaseIterable, Sendable {
    case webCache = "web_cache"
    case codeCache = "code_cache"
    case favicons = "favicons"
    case offlineStorage = "offline_storage"
    case cookies = "cookies"
    case history = "history"
    case autofill = "autofill"
    case passwords = "passwords"
    case downloads = "downloads"
    case crashLogs = "crash_logs"
    
    public var displayName: String {
        switch self {
        case .webCache: return "Web ve Medya Önbelleği"
        case .codeCache: return "V8 / JIT Derlenmiş Kod Deposu"
        case .favicons: return "Site Simgeleri (Favicons)"
        case .offlineStorage: return "Çevrimdışı Web & Servis Deposu"
        case .cookies: return "Oturum Çerezleri"
        case .history: return "Tarama ve Arama Geçmişi"
        case .autofill: return "Otomatik Doldurma & Form Verileri"
        case .passwords: return "Kayıtlı Parolalar & Şifreler"
        case .downloads: return "İndirme Geçmişi Kayıtları"
        case .crashLogs: return "Hata ve Teşhis Günlükleri"
        }
    }
    
    public var icon: String {
        switch self {
        case .webCache: return "globe"
        case .codeCache: return "chevron.left.forwardslash.chevron.right"
        case .favicons: return "photo.stack"
        case .offlineStorage: return "internaldrive"
        case .cookies: return "lock.badge.clock"
        case .history: return "clock.arrow.circlepath"
        case .autofill: return "text.cursor"
        case .passwords: return "key.fill"
        case .downloads: return "arrow.down.circle"
        case .crashLogs: return "exclamationmark.triangle"
        }
    }
    
    /// Varsayılan olarak Akıllı Arınma'da veya Tarayıcı listesinde seçili gelsin mi?
    public var defaultSelected: Bool {
        switch self {
        case .webCache, .codeCache, .favicons, .offlineStorage, .crashLogs:
            return true
        case .cookies, .history, .autofill, .passwords, .downloads:
            return false // Parola, oturum veya şahsi veri kaybı olmaması için varsayılan olarak KESİNLİKLE KAPALI
        }
    }
    
    /// Kullanıcı seçerse dikkat uyarısı gösterilecek mi?
    public var isCaution: Bool {
        switch self {
        case .passwords, .cookies, .history, .autofill:
            return true
        default:
            return false
        }
    }
    
    /// Kritik güvenlik kategorisi mi (Parola)?
    public var isCritical: Bool {
        self == .passwords
    }
    
    public var warningNote: String? {
        switch self {
        case .passwords:
            return "Kayıtlı web giriş şifreleriniz kalıcı silinir!"
        case .cookies:
            return "Sitelerdeki açık oturumlarınız sonlanır."
        case .history:
            return "Ziyaret edilen URL ve arama geçmişi silinir."
        case .autofill:
            return "Kayıtlı form ve adres doldurma verileri silinir."
        default:
            return nil
        }
    }
}

public struct BrowserSubItem: Identifiable, Sendable {
    public let id: String
    public let type: BrowserDataType
    public let name: String
    public let path: String
    public var size: Int64
    public var isSelected: Bool
    public let descriptionText: String
    
    public init(
        id: String = UUID().uuidString,
        type: BrowserDataType,
        name: String,
        path: String,
        size: Int64,
        isSelected: Bool,
        descriptionText: String
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.path = path
        self.size = size
        self.isSelected = isSelected
        self.descriptionText = descriptionText
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct DetectedBrowser: Identifiable, Sendable {
    public let id: String // bundleId
    public let name: String // "Safari", "Google Chrome", etc.
    public let appPath: String // "/Applications/Safari.app"
    public let bundleId: String
    public var isRunning: Bool
    public var items: [BrowserSubItem]
    public var isSelected: Bool
    
    public init(
        id: String,
        name: String,
        appPath: String,
        bundleId: String,
        isRunning: Bool = false,
        items: [BrowserSubItem] = [],
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.bundleId = bundleId
        self.isRunning = isRunning
        self.items = items
        self.isSelected = isSelected
    }
    
    public var totalSelectedSize: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    public var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
    
    public var formattedSelectedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

public final class BrowserCacheEngine: Sendable {
    public static let shared = BrowserCacheEngine()
    
    public init() {}
    
    private enum BrowserKind {
        case safari(containerName: String)
        case chromium(dataSubPath: String, cacheSubPath: String)
        case gecko(profileSubPath: String, cacheSubPath: String)
    }
    
    private struct BrowserSpec {
        let name: String
        let bundleId: String
        let appPaths: [String]
        let kind: BrowserKind
    }
    
    private var browserSpecs: [BrowserSpec] {
        return [
            // 1. Apple Safari
            BrowserSpec(
                name: "Safari",
                bundleId: "com.apple.Safari",
                appPaths: [
                    "/Applications/Safari.app",
                    "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
                    "/System/Applications/Safari.app"
                ],
                kind: .safari(containerName: "com.apple.Safari")
            ),
            
            // 2. Safari Technology Preview
            BrowserSpec(
                name: "Safari Technology Preview",
                bundleId: "com.apple.SafariTechnologyPreview",
                appPaths: ["/Applications/Safari Technology Preview.app"],
                kind: .safari(containerName: "com.apple.SafariTechnologyPreview")
            ),
            
            // 3. Google Chrome
            BrowserSpec(
                name: "Google Chrome",
                bundleId: "com.google.Chrome",
                appPaths: ["/Applications/Google Chrome.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/Google/Chrome",
                    cacheSubPath: "Library/Caches/Google/Chrome"
                )
            ),
            
            // 4. Google Chrome Canary
            BrowserSpec(
                name: "Google Chrome Canary",
                bundleId: "com.google.Chrome.canary",
                appPaths: ["/Applications/Google Chrome Canary.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/Google/Chrome Canary",
                    cacheSubPath: "Library/Caches/Google/Chrome Canary"
                )
            ),
            
            // 5. Firefox Developer Edition
            BrowserSpec(
                name: "Firefox Developer Edition",
                bundleId: "org.mozilla.firefoxdeveloperedition",
                appPaths: ["/Applications/Firefox Developer Edition.app"],
                kind: .gecko(
                    profileSubPath: "Library/Application Support/Firefox/Profiles",
                    cacheSubPath: "Library/Caches/Firefox/Profiles"
                )
            ),
            
            // 6. Mozilla Firefox
            BrowserSpec(
                name: "Mozilla Firefox",
                bundleId: "org.mozilla.firefox",
                appPaths: ["/Applications/Firefox.app"],
                kind: .gecko(
                    profileSubPath: "Library/Application Support/Firefox/Profiles",
                    cacheSubPath: "Library/Caches/Firefox/Profiles"
                )
            ),
            
            // 7. Firefox Nightly
            BrowserSpec(
                name: "Firefox Nightly",
                bundleId: "org.mozilla.nightly",
                appPaths: ["/Applications/Firefox Nightly.app"],
                kind: .gecko(
                    profileSubPath: "Library/Application Support/Firefox/Profiles",
                    cacheSubPath: "Library/Caches/Firefox/Profiles"
                )
            ),
            
            // 8. Brave Browser
            BrowserSpec(
                name: "Brave Browser",
                bundleId: "com.brave.Browser",
                appPaths: ["/Applications/Brave Browser.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/BraveSoftware/Brave-Browser",
                    cacheSubPath: "Library/Caches/BraveSoftware/Brave-Browser"
                )
            ),
            
            // 9. Arc Browser
            BrowserSpec(
                name: "Arc",
                bundleId: "company.thebrowser.Browser",
                appPaths: ["/Applications/Arc.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/Arc/User Data",
                    cacheSubPath: "Library/Caches/company.thebrowser.Browser"
                )
            ),
            
            // 10. Microsoft Edge
            BrowserSpec(
                name: "Microsoft Edge",
                bundleId: "com.microsoft.edgemac",
                appPaths: ["/Applications/Microsoft Edge.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/Microsoft Edge",
                    cacheSubPath: "Library/Caches/Microsoft Edge"
                )
            ),
            
            // 11. Opera
            BrowserSpec(
                name: "Opera",
                bundleId: "com.operasoftware.Opera",
                appPaths: ["/Applications/Opera.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/com.operasoftware.Opera",
                    cacheSubPath: "Library/Caches/com.operasoftware.Opera"
                )
            ),
            
            // 12. Opera GX
            BrowserSpec(
                name: "Opera GX",
                bundleId: "com.operasoftware.OperaGX",
                appPaths: ["/Applications/Opera GX.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/com.operasoftware.OperaGX",
                    cacheSubPath: "Library/Caches/com.operasoftware.OperaGX"
                )
            ),
            
            // 13. Vivaldi
            BrowserSpec(
                name: "Vivaldi",
                bundleId: "com.vivaldi.Vivaldi",
                appPaths: ["/Applications/Vivaldi.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/Vivaldi",
                    cacheSubPath: "Library/Caches/Vivaldi"
                )
            ),
            
            // 14. Orion
            BrowserSpec(
                name: "Orion",
                bundleId: "com.kagi.kagimacOS",
                appPaths: ["/Applications/Orion.app"],
                kind: .safari(containerName: "com.kagi.kagimacOS")
            ),
            
            // 15. DuckDuckGo Browser
            BrowserSpec(
                name: "DuckDuckGo",
                bundleId: "com.duckduckgo.macos.browser",
                appPaths: ["/Applications/DuckDuckGo.app"],
                kind: .safari(containerName: "com.duckduckgo.macos.browser")
            ),
            
            // 16. Zen Browser
            BrowserSpec(
                name: "Zen Browser",
                bundleId: "app.zen-browser.zen",
                appPaths: ["/Applications/Zen Browser.app"],
                kind: .gecko(
                    profileSubPath: "Library/Application Support/zen/Profiles",
                    cacheSubPath: "Library/Caches/zen"
                )
            ),
            
            // 17. Floorp
            BrowserSpec(
                name: "Floorp",
                bundleId: "org.floorp.floorp",
                appPaths: ["/Applications/Floorp.app"],
                kind: .gecko(
                    profileSubPath: "Library/Application Support/Floorp/Profiles",
                    cacheSubPath: "Library/Caches/floorp"
                )
            ),
            
            // 18. Chromium
            BrowserSpec(
                name: "Chromium",
                bundleId: "org.chromium.Chromium",
                appPaths: ["/Applications/Chromium.app"],
                kind: .chromium(
                    dataSubPath: "Library/Application Support/Chromium",
                    cacheSubPath: "Library/Caches/Chromium"
                )
            )
        ]
    }
    
    /// Sistemde YALNIZCA KURULU OLAN tarayıcıları ve onların alt kategorilerini derinlemesine tarar
    public func detectInstalledBrowsers() async -> [DetectedBrowser] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var detected: [DetectedBrowser] = []
        
        for spec in browserSpecs {
            // 1. Tarayıcının sistemde kurulu olup olmadığını denetle
            var installedPath: String? = nil
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spec.bundleId) {
                installedPath = appURL.path
            } else {
                installedPath = spec.appPaths.first(where: { fm.fileExists(atPath: $0) })
            }
            
            // Eğer uygulama /Applications'ta yoksa ama ~/Applications altındaysa da bul
            if installedPath == nil {
                let userAppPath = (home as NSString).appendingPathComponent(spec.appPaths.first ?? "")
                if fm.fileExists(atPath: userAppPath) {
                    installedPath = userAppPath
                }
            }
            
            guard let appPath = installedPath else {
                continue
            }
            
            // 2. Çalışma durumunu denetle
            let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: spec.bundleId).isEmpty
            
            // 3. Alt kategorileri derinlemesine tara
            var subItems: [BrowserSubItem] = []
            
            switch spec.kind {
            case .safari(let containerName):
                subItems = scanSafari(containerName: containerName, bundleId: spec.bundleId)
                
            case .chromium(let dataSubPath, let cacheSubPath):
                let fullDataDir = (home as NSString).appendingPathComponent(dataSubPath)
                let fullCacheDir = (home as NSString).appendingPathComponent(cacheSubPath)
                subItems = scanChromium(dataDir: fullDataDir, cacheDir: fullCacheDir, browserName: spec.name)
                
            case .gecko(let profileSubPath, let cacheSubPath):
                let fullProfileDir = (home as NSString).appendingPathComponent(profileSubPath)
                let fullCacheDir = (home as NSString).appendingPathComponent(cacheSubPath)
                subItems = scanGecko(profileDir: fullProfileDir, cacheDir: fullCacheDir, browserName: spec.name)
            }
            
            // Eğer tarayıcı kuruluysa ama önbellekler temizse bile tarayıcıyı listede tertemiz olarak göster
            if subItems.isEmpty {
                subItems.append(BrowserSubItem(
                    type: .webCache,
                    name: "Genel Web Önbelleği",
                    path: appPath,
                    size: 0,
                    isSelected: false,
                    descriptionText: "Tarayıcı depoları tertemiz durumda."
                ))
            }
            
            detected.append(DetectedBrowser(
                id: spec.bundleId,
                name: spec.name,
                appPath: appPath,
                bundleId: spec.bundleId,
                isRunning: isRunning,
                items: subItems,
                isSelected: true
            ))
        }
        
        return detected
    }
    
    // MARK: - Safari / WebKit Derin Tarama
    private func scanSafari(containerName: String, bundleId: String) -> [BrowserSubItem] {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        var items: [BrowserSubItem] = []
        
        let rules: [(type: BrowserDataType, path: String, name: String, desc: String)] = [
            (
                .webCache,
                (home as NSString).appendingPathComponent("Library/Containers/\(containerName)/Data/Library/Caches"),
                "Safari WebKit & Sayfa Önbelleği",
                "Ziyaret edilen web sayfalarından indirilen medya, stil, resim ve komut dosyaları."
            ),
            (
                .webCache,
                (home as NSString).appendingPathComponent("Library/Caches/\(bundleId)"),
                "Safari HTTP Ağ Önbelleği",
                "Safari ağ yanıtları ve geçici indirme ara belleği."
            ),
            (
                .favicons,
                (home as NSString).appendingPathComponent("Library/Safari/Favicon Cache"),
                "Safari Site Simgeleri (Favicons)",
                "Sitelerin yerel simge ve dokunma ikonları deposu."
            ),
            (
                .favicons,
                (home as NSString).appendingPathComponent("Library/Safari/Touch Icons Cache"),
                "Safari Dokunmatik Simgeler",
                "Hızlı arama ve yer imi dokunma simgeleri."
            ),
            (
                .offlineStorage,
                (home as NSString).appendingPathComponent("Library/WebKit/\(bundleId)"),
                "WebKit Render & HTML5 Deposu",
                "WebKit motorunun geçici işlem ve render verileri."
            ),
            (
                .cookies,
                (home as NSString).appendingPathComponent("Library/Containers/\(containerName)/Data/Library/Cookies"),
                "Safari Oturum Çerezleri",
                "Web sitelerinin bıraktığı oturum ve kimlik çerezleri."
            ),
            (
                .history,
                (home as NSString).appendingPathComponent("Library/Safari/History.db"),
                "Safari Tarama Geçmişi",
                "Ziyaret edilen web sayfaları URL ve başlık geçmişi."
            )
        ]
        
        for rule in rules {
            if fm.fileExists(atPath: rule.path) {
                let sz = FastScanner.shared.getPathSize(path: rule.path)
                if sz > 1_000 {
                    items.append(BrowserSubItem(
                        type: rule.type,
                        name: rule.name,
                        path: rule.path,
                        size: sz,
                        isSelected: rule.type.defaultSelected,
                        descriptionText: rule.desc
                    ))
                }
            }
        }
        
        return items
    }
    
    // MARK: - Chromium Tabanlı Derin Profil Taraması (Chrome, Brave, Arc, Edge, Opera, Vivaldi)
    private func scanChromium(dataDir: String, cacheDir: String, browserName: String) -> [BrowserSubItem] {
        let fm = FileManager.default
        var items: [BrowserSubItem] = []
        
        // 1. Caches Dizini Taraması
        if fm.fileExists(atPath: cacheDir) {
            if let entries = try? fm.contentsOfDirectory(atPath: cacheDir) {
                for e in entries {
                    let profileCache = (cacheDir as NSString).appendingPathComponent(e)
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: profileCache, isDirectory: &isDir), isDir.boolValue {
                        let cachePath = (profileCache as NSString).appendingPathComponent("Cache")
                        let codeCachePath = (profileCache as NSString).appendingPathComponent("Code Cache")
                        
                        if fm.fileExists(atPath: cachePath) {
                            let sz = FastScanner.shared.getPathSize(path: cachePath)
                            if sz > 1_000 {
                                items.append(BrowserSubItem(
                                    type: .webCache,
                                    name: "Web & Medya Önbelleği (\(e))",
                                    path: cachePath,
                                    size: sz,
                                    isSelected: true,
                                    descriptionText: "HTTP/HTTPS önbelleğe alınmış resimler, scriptler ve sayfa varlıkları."
                                ))
                            }
                        }
                        
                        if fm.fileExists(atPath: codeCachePath) {
                            let sz = FastScanner.shared.getPathSize(path: codeCachePath)
                            if sz > 1_000 {
                                items.append(BrowserSubItem(
                                    type: .codeCache,
                                    name: "V8 Derlenmiş Kod Deposu (\(e))",
                                    path: codeCachePath,
                                    size: sz,
                                    isSelected: true,
                                    descriptionText: "JavaScript kodlarının önceden derlenmiş V8 bayt kodları."
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Application Support Profilleri Taraması (Default, Profile 1, Profile 2...)
        if fm.fileExists(atPath: dataDir) {
            // Global GPU Shader ve Gölgelendirici Önbellekleri
            let globalCaches = [
                ("ShaderCache", "Shader Derleyici Deposu"),
                ("GrShaderCache", "GrShader Grafik Deposu"),
                ("GraphiteDawnCache", "Graphite Dawn Render Deposu"),
                ("GPUPersistentCache", "GPU Sürekli Render Önbelleği")
            ]
            for (sub, label) in globalCaches {
                let target = (dataDir as NSString).appendingPathComponent(sub)
                if fm.fileExists(atPath: target) {
                    let sz = FastScanner.shared.getPathSize(path: target)
                    if sz > 10_000 {
                        items.append(BrowserSubItem(
                            type: .offlineStorage,
                            name: label,
                            path: target,
                            size: sz,
                            isSelected: true,
                            descriptionText: "Donanımsal grafik hızlandırma ve render ara belleği."
                        ))
                    }
                }
            }
            
            // Çökme günlükleri (Crashpad)
            let crashpad = (dataDir as NSString).appendingPathComponent("Crashpad")
            if fm.fileExists(atPath: crashpad) {
                let sz = FastScanner.shared.getPathSize(path: crashpad)
                if sz > 5_000 {
                    items.append(BrowserSubItem(
                        type: .crashLogs,
                        name: "\(browserName) Hata & Teşhis Günlükleri",
                        path: crashpad,
                        size: sz,
                        isSelected: true,
                        descriptionText: "Eski çökme ve hata raporları."
                    ))
                }
            }
            
            // Profilleri tara
            if let entries = try? fm.contentsOfDirectory(atPath: dataDir) {
                for e in entries where e == "Default" || e.hasPrefix("Profile ") {
                    let profPath = (dataDir as NSString).appendingPathComponent(e)
                    let pLabel = e == "Default" ? "Ana Profil" : e
                    
                    let targets: [(type: BrowserDataType, rel: String, name: String, desc: String)] = [
                        (
                            .offlineStorage,
                            "Service Worker/CacheStorage",
                            "Service Worker & PWA Deposu (\(pLabel))",
                            "Çevrimdışı web uygulaması ve Progressive Web App (PWA) önbellekleri."
                        ),
                        (
                            .offlineStorage,
                            "File System",
                            "Web Dosya Sistemi Deposu (\(pLabel))",
                            "Web sitelerinin yerel depolama dosya sistemi havuzu."
                        ),
                        (
                            .offlineStorage,
                            "IndexedDB",
                            "IndexedDB Çevrimdışı Veritabanı (\(pLabel))",
                            "Web sitelerinin yerel IndexedDB önbellek tabloları."
                        ),
                        (
                            .offlineStorage,
                            "GPUCache",
                            "GPU & WebGL Gölgelendiricileri (\(pLabel))",
                            "Donanımsal grafik hızlandırma ara belleği."
                        ),
                        (
                            .favicons,
                            "Favicons",
                            "Site Simgeleri (Favicons) (\(pLabel))",
                            "Site küçük resimleri ve ikon veritabanı."
                        ),
                        (
                            .history,
                            "History",
                            "Tarama ve Arama Geçmişi (\(pLabel))",
                            "Ziyaret edilen web sayfaları ve adres çubuğu arama geçmişi."
                        ),
                        (
                            .cookies,
                            "Network/Cookies",
                            "Oturum Çerezleri (\(pLabel))",
                            "Web sitelerinde oturum açmanızı sağlayan çerezler."
                        ),
                        (
                            .autofill,
                            "Web Data",
                            "Otomatik Doldurma & Form Verileri (\(pLabel))",
                            "Form tamamlama, arama önerileri ve adres tamamlama veritabanı."
                        ),
                        (
                            .passwords,
                            "Login Data",
                            "Kayıtlı Parolalar & Şifreler (\(pLabel))",
                            "Tarayıcıda kayıtlı web sitesi kullanıcı adı ve giriş parolaları."
                        )
                    ]
                    
                    for t in targets {
                        let full = (profPath as NSString).appendingPathComponent(t.rel)
                        if fm.fileExists(atPath: full) {
                            let sz = FastScanner.shared.getPathSize(path: full)
                            if sz > 1_000 {
                                items.append(BrowserSubItem(
                                    type: t.type,
                                    name: t.name,
                                    path: full,
                                    size: sz,
                                    isSelected: t.type.defaultSelected,
                                    descriptionText: t.desc
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    // MARK: - Gecko / Firefox Tabanlı Derin Profil Taraması
    private func scanGecko(profileDir: String, cacheDir: String, browserName: String) -> [BrowserSubItem] {
        let fm = FileManager.default
        var items: [BrowserSubItem] = []
        
        // 1. Profil Dizinleri
        if fm.fileExists(atPath: profileDir) {
            if let profiles = try? fm.contentsOfDirectory(atPath: profileDir) {
                for prof in profiles {
                    let profPath = (profileDir as NSString).appendingPathComponent(prof)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: profPath, isDirectory: &isDir), isDir.boolValue else { continue }
                    
                    let pLabel = String(prof.prefix(12))
                    
                    let targets: [(type: BrowserDataType, rel: String, name: String, desc: String)] = [
                        (
                            .offlineStorage,
                            "storage",
                            "Çevrimdışı Web & IndexedDB Deposu (\(pLabel))",
                            "Web sitelerinin depoladığı çevrimdışı önbellekler ve IndexedDB veritabanı."
                        ),
                        (
                            .favicons,
                            "favicons.sqlite",
                            "Site Simgeleri (Favicons) (\(pLabel))",
                            "Yer imleri ve geçmiş sitelerin favicon veritabanı."
                        ),
                        (
                            .history,
                            "places.sqlite",
                            "Tarama Geçmişi & Yer İmleri Kayıtları (\(pLabel))",
                            "Ziyaret edilen URL geçmişi ve arama kayıtları."
                        ),
                        (
                            .cookies,
                            "cookies.sqlite",
                            "Oturum Çerezleri (\(pLabel))",
                            "Sitelerdeki açık oturumları saklayan çerez veritabanı."
                        ),
                        (
                            .autofill,
                            "formhistory.sqlite",
                            "Otomatik Doldurma & Form Verileri (\(pLabel))",
                            "Web formlarında girilen otomatik tamamlama verileri."
                        ),
                        (
                            .passwords,
                            "logins.json",
                            "Kayıtlı Parolalar & Giriş Verileri (\(pLabel))",
                            "Tarayıcıda kayıtlı kullanıcı adı ve şifreler."
                        ),
                        (
                            .passwords,
                            "key4.db",
                            "Şifreli Parola Anahtarlık Deposu (\(pLabel))",
                            "Firefox şifreleme anahtarları ve şifre kasası."
                        ),
                        (
                            .offlineStorage,
                            "sessionstore-backups",
                            "Sekme & Oturum Yedekleri (\(pLabel))",
                            "Kapanan pencerelerin ve sekmelerin kurtarma yedekleri."
                        ),
                        (
                            .crashLogs,
                            "crashes",
                            "Çökme & Hata Raporları (\(pLabel))",
                            "Eski hata teşhis ve çökme günlükleri."
                        )
                    ]
                    
                    for t in targets {
                        let full = (profPath as NSString).appendingPathComponent(t.rel)
                        if fm.fileExists(atPath: full) {
                            let sz = FastScanner.shared.getPathSize(path: full)
                            if sz > 1_000 {
                                items.append(BrowserSubItem(
                                    type: t.type,
                                    name: t.name,
                                    path: full,
                                    size: sz,
                                    isSelected: t.type.defaultSelected,
                                    descriptionText: t.desc
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Cache Dizinleri (cache2)
        if fm.fileExists(atPath: cacheDir) {
            if let profiles = try? fm.contentsOfDirectory(atPath: cacheDir) {
                for prof in profiles {
                    let profCache = (cacheDir as NSString).appendingPathComponent(prof)
                    let cache2 = (profCache as NSString).appendingPathComponent("cache2")
                    if fm.fileExists(atPath: cache2) {
                        let sz = FastScanner.shared.getPathSize(path: cache2)
                        if sz > 5_000 {
                            items.append(BrowserSubItem(
                                type: .webCache,
                                name: "Firefox Web & Medya Önbelleği (\(prof.prefix(8)))",
                                path: cache2,
                                size: sz,
                                isSelected: true,
                                descriptionText: "HTTP/HTTPS ağ ve medya önbelleği."
                            ))
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    /// Unified CleanerEngine için düz CleanItem listesi üretir
    public func scanBrowserCaches() async -> [CleanItem] {
        let browsers = await detectInstalledBrowsers()
        var items: [CleanItem] = []
        
        for b in browsers {
            for sub in b.items where sub.type.defaultSelected && sub.size > 0 { // Yalnızca güvenli önbellekleri Akıllı Arınma'ya dahil et
                items.append(CleanItem(
                    name: "\(b.name): \(sub.name)",
                    path: sub.path,
                    size: sub.size,
                    category: .browserCaches,
                    safety: .safe,
                    itemDescription: sub.descriptionText,
                    isSelected: true
                ))
            }
        }
        
        return items
    }
    
    /// Seçilen tarayıcı verilerini diskten siler
    public func cleanBrowserItems(items: [BrowserSubItem]) async -> Int64 {
        var freed: Int64 = 0
        let fm = FileManager.default
        
        for item in items where item.isSelected && item.size > 0 {
            guard SafetyFilter.shared.isSafeToDelete(path: item.path) else { continue }
            
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir) {
                do {
                    if isDir.boolValue {
                        if let files = try? fm.contentsOfDirectory(atPath: item.path) {
                            for f in files {
                                let sub = (item.path as NSString).appendingPathComponent(f)
                                try? fm.removeItem(atPath: sub)
                            }
                        }
                    } else {
                        try fm.removeItem(atPath: item.path)
                        
                        // SQLite ve journal ek dosyalarını da temizle
                        if item.type == .history || item.type == .passwords || item.type == .autofill || item.type == .favicons || item.type == .cookies {
                            let wal = item.path + "-wal"
                            let shm = item.path + "-shm"
                            let journal = item.path + "-journal"
                            try? fm.removeItem(atPath: wal)
                            try? fm.removeItem(atPath: shm)
                            try? fm.removeItem(atPath: journal)
                        }
                    }
                    freed += item.size
                } catch {}
            }
        }
        
        return freed
    }
}
