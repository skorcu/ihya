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
    case downloads = "downloads"
    case crashLogs = "crash_logs"
    
    public var displayName: String {
        switch self {
        case self: return "Web ve Medya Önbelleği"
        case .webCache: return "Web ve Medya Önbelleği"
        case .codeCache: return "V8 Derlenmiş Kod Deposu"
        case .favicons: return "Site Simgeleri (Favicons)"
        case .offlineStorage: return "Çevrimdışı Web ve Servis Deposu"
        case .cookies: return "Oturum Çerezleri"
        case .history: return "Tarama ve Arama Geçmişi"
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
        case .downloads: return "arrow.down.circle"
        case .crashLogs: return "exclamationmark.triangle"
        }
    }
    
    /// Varsayılan olarak Akıllı Arınma'da seçili gelsin mi?
    public var defaultSelected: Bool {
        switch self {
        case .webCache, .codeCache, .favicons, .offlineStorage, .crashLogs:
            return true
        case .cookies, .history, .downloads:
            return false // Parola/oturum kaybı olmaması için varsayılan KAPALI
        }
    }
    
    /// Kullanıcı seçerse dikkat uyarısı gösterilecek mi?
    public var isCaution: Bool {
        switch self {
        case .cookies, .history:
            return true
        default:
            return false
        }
    }
    
    public var warningNote: String? {
        switch self {
        case .cookies:
            return "Sitelerdeki açık oturumlarınız sonlanır."
        case .history:
            return "Ziyaret edilen URL ve arama geçmişi silinir."
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
    
    /// Bilinen tüm Mac tarayıcı tanımları
    private struct BrowserSpec {
        let name: String
        let bundleId: String
        let appPaths: [String]
        let cacheRules: [(type: BrowserDataType, subPath: String, name: String, desc: String)]
    }
    
    private var browserSpecs: [BrowserSpec] {
        let home = NSHomeDirectory()
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
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Caches"),
                        "Safari WebKit & Sayfa Önbelleği",
                        "Ziyaret edilen web sayfalarından indirilen medya, stil ve komut dosyaları."
                    ),
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/com.apple.Safari"),
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
                        (home as NSString).appendingPathComponent("Library/WebKit/com.apple.Safari"),
                        "WebKit WebProcess & HTML5 Deposu",
                        "WebKit motorunun geçici işlem ve render verileri."
                    ),
                    (
                        .cookies,
                        (home as NSString).appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Cookies"),
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
            ),
            
            // 2. Safari Technology Preview
            BrowserSpec(
                name: "Safari Technology Preview",
                bundleId: "com.apple.SafariTechnologyPreview",
                appPaths: ["/Applications/Safari Technology Preview.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Containers/com.apple.SafariTechnologyPreview/Data/Library/Caches"),
                        "Safari TP WebKit Önbelleği",
                        "Teknoloji önizleme sürümü geçici render deposu."
                    )
                ]
            ),
            
            // 3. Google Chrome
            BrowserSpec(
                name: "Google Chrome",
                bundleId: "com.google.Chrome",
                appPaths: ["/Applications/Google Chrome.app", (home as NSString).appendingPathComponent("Applications/Google Chrome.app")],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Google/Chrome"),
                        "Chrome Web & Medya Önbelleği",
                        "HTTP/HTTPS önbelleğe alınmış resimler, scriptler ve sayfa varlıkları."
                    ),
                    (
                        .codeCache,
                        (home as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Default/Code Cache"),
                        "Chrome V8 Derlenmiş Kod Deposu",
                        "JavaScript kodlarının önceden derlenmiş bayt kodları (V8)."
                    ),
                    (
                        .offlineStorage,
                        (home as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Default/GPUCache"),
                        "Chrome GPU & WebGL Gölgelendiricileri",
                        "Donanımsal grafik hızlandırma ara belleği."
                    ),
                    (
                        .offlineStorage,
                        (home as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage"),
                        "Chrome Service Worker Deposu",
                        "Çevrimdışı web uygulaması ve PWA önbellekleri."
                    ),
                    (
                        .favicons,
                        (home as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Default/Favicons"),
                        "Chrome Favicon Deposu",
                        "Site küçük resimleri ve ikon veritabanı."
                    ),
                    (
                        .cookies,
                        (home as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Default/Network/Cookies"),
                        "Chrome Çerezleri & Oturumlar",
                        "Sitelerde aktif oturum açma çerezleri."
                    ),
                    (
                        .history,
                        (home as NSString).appendingPathComponent("Library/Application Support/Google/Chrome/Default/History"),
                        "Chrome Tarama Geçmişi",
                        "Ziyaret edilen sayfalar ve arama geçmişi."
                    )
                ]
            ),
            
            // 4. Google Chrome Canary
            BrowserSpec(
                name: "Google Chrome Canary",
                bundleId: "com.google.Chrome.canary",
                appPaths: ["/Applications/Google Chrome Canary.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Google/Chrome Canary"),
                        "Chrome Canary Web Önbelleği",
                        "Canary sürümü web ve render ara belleği."
                    )
                ]
            ),
            
            // 5. Firefox Developer Edition
            BrowserSpec(
                name: "Firefox Developer Edition",
                bundleId: "org.mozilla.firefoxdeveloperedition",
                appPaths: ["/Applications/Firefox Developer Edition.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Firefox/Profiles"),
                        "Firefox Dev Ağ Önbelleği",
                        "Geliştirici sürümü HTTP/HTTPS sayfa ve medya önbelleği."
                    ),
                    (
                        .offlineStorage,
                        (home as NSString).appendingPathComponent("Library/Caches/Mozilla/updates"),
                        "Mozilla Güncelleme Geçici Dosyaları",
                        "Geçici güncelleme paketleri ve günlükler."
                    )
                ]
            ),
            
            // 6. Mozilla Firefox
            BrowserSpec(
                name: "Mozilla Firefox",
                bundleId: "org.mozilla.firefox",
                appPaths: ["/Applications/Firefox.app", (home as NSString).appendingPathComponent("Applications/Firefox.app")],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Firefox/Profiles"),
                        "Firefox Web & Sayfa Önbelleği",
                        "HTTP/HTTPS ağ ve medya önbelleği."
                    )
                ]
            ),
            
            // 7. Firefox Nightly
            BrowserSpec(
                name: "Firefox Nightly",
                bundleId: "org.mozilla.nightly",
                appPaths: ["/Applications/Firefox Nightly.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Firefox/Profiles"),
                        "Firefox Nightly Web Önbelleği",
                        "Gecelik derleme ağ önbelleği."
                    )
                ]
            ),
            
            // 8. Brave Browser
            BrowserSpec(
                name: "Brave Browser",
                bundleId: "com.brave.Browser",
                appPaths: ["/Applications/Brave Browser.app", (home as NSString).appendingPathComponent("Applications/Brave Browser.app")],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/BraveSoftware/Brave-Browser"),
                        "Brave Web Önbelleği",
                        "Brave HTTP/HTTPS medya ve ağ paketleri."
                    ),
                    (
                        .codeCache,
                        (home as NSString).appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/Code Cache"),
                        "Brave V8 Kod Deposu",
                        "Önceden derlenmiş JavaScript kodları."
                    ),
                    (
                        .offlineStorage,
                        (home as NSString).appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/GPUCache"),
                        "Brave GPU ve Render Önbelleği",
                        "Grafik hızlandırma verileri."
                    ),
                    (
                        .history,
                        (home as NSString).appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser/Default/History"),
                        "Brave Tarama Geçmişi",
                        "Ziyaret geçmişi veritabanı."
                    )
                ]
            ),
            
            // 9. Arc Browser
            BrowserSpec(
                name: "Arc",
                bundleId: "company.thebrowser.Browser",
                appPaths: ["/Applications/Arc.app", (home as NSString).appendingPathComponent("Applications/Arc.app")],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/company.thebrowser.Browser"),
                        "Arc Web & Medya Önbelleği",
                        "Arc HTTP ve sayfa önbelleği."
                    ),
                    (
                        .codeCache,
                        (home as NSString).appendingPathComponent("Library/Application Support/Arc/User Data/Default/Code Cache"),
                        "Arc V8 Kod Deposu",
                        "JavaScript bayt kodları."
                    ),
                    (
                        .history,
                        (home as NSString).appendingPathComponent("Library/Application Support/Arc/User Data/Default/History"),
                        "Arc Tarama Geçmişi",
                        "Sayfa ziyaret geçmişi."
                    )
                ]
            ),
            
            // 10. Microsoft Edge
            BrowserSpec(
                name: "Microsoft Edge",
                bundleId: "com.microsoft.edgemac",
                appPaths: ["/Applications/Microsoft Edge.app", (home as NSString).appendingPathComponent("Applications/Microsoft Edge.app")],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Microsoft Edge"),
                        "Edge Web Önbelleği",
                        "Edge ağ ve resim önbelleği."
                    ),
                    (
                        .codeCache,
                        (home as NSString).appendingPathComponent("Library/Application Support/Microsoft Edge/Default/Code Cache"),
                        "Edge V8 Kod Deposu",
                        "Derlenmiş JavaScript kodları."
                    ),
                    (
                        .history,
                        (home as NSString).appendingPathComponent("Library/Application Support/Microsoft Edge/Default/History"),
                        "Edge Tarama Geçmişi",
                        "Edge ziyaret geçmişi."
                    )
                ]
            ),
            
            // 11. Opera
            BrowserSpec(
                name: "Opera",
                bundleId: "com.operasoftware.Opera",
                appPaths: ["/Applications/Opera.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/com.operasoftware.Opera"),
                        "Opera Web Önbelleği",
                        "Opera web ve render deposu."
                    )
                ]
            ),
            
            // 12. Opera GX
            BrowserSpec(
                name: "Opera GX",
                bundleId: "com.operasoftware.OperaGX",
                appPaths: ["/Applications/Opera GX.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/com.operasoftware.OperaGX"),
                        "Opera GX Web Önbelleği",
                        "GX oyun tarayıcısı render önbelleği."
                    )
                ]
            ),
            
            // 13. Vivaldi
            BrowserSpec(
                name: "Vivaldi",
                bundleId: "com.vivaldi.Vivaldi",
                appPaths: ["/Applications/Vivaldi.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Vivaldi"),
                        "Vivaldi Web Önbelleği",
                        "Vivaldi ağ ve resim önbelleği."
                    )
                ]
            ),
            
            // 14. Orion
            BrowserSpec(
                name: "Orion",
                bundleId: "com.kagi.kagimacOS",
                appPaths: ["/Applications/Orion.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/com.kagi.kagimacOS"),
                        "Orion WebKit Önbelleği",
                        "WebKit tabanlı hafif önbellek."
                    )
                ]
            ),
            
            // 15. Tor Browser
            BrowserSpec(
                name: "Tor Browser",
                bundleId: "org.torproject.torbrowser",
                appPaths: ["/Applications/Tor Browser.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Application Support/TorBrowser-Data/Browser/Caches"),
                        "Tor Geçici Ağ Önbelleği",
                        "Tor oturumu geçici ağ dosyaları."
                    )
                ]
            ),
            
            // 16. DuckDuckGo Browser
            BrowserSpec(
                name: "DuckDuckGo",
                bundleId: "com.duckduckgo.macos.browser",
                appPaths: ["/Applications/DuckDuckGo.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/com.duckduckgo.macos.browser"),
                        "DuckDuckGo Web Önbelleği",
                        "Gizlilik odaklı tarayıcı ağ önbelleği."
                    ),
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Containers/com.duckduckgo.macos.browser/Data/Library/Caches"),
                        "DuckDuckGo Konteyner Önbelleği",
                        "Korumalı alan render önbelleği."
                    )
                ]
            ),
            
            // 17. Zen Browser
            BrowserSpec(
                name: "Zen Browser",
                bundleId: "app.zen-browser.zen",
                appPaths: ["/Applications/Zen Browser.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/zen"),
                        "Zen Web Önbelleği",
                        "Zen tarayıcı HTTP önbelleği."
                    )
                ]
            ),
            
            // 18. Floorp
            BrowserSpec(
                name: "Floorp",
                bundleId: "org.floorp.floorp",
                appPaths: ["/Applications/Floorp.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/floorp"),
                        "Floorp Web Önbelleği",
                        "Floorp HTTP önbelleği."
                    )
                ]
            ),
            
            // 19. Chromium
            BrowserSpec(
                name: "Chromium",
                bundleId: "org.chromium.Chromium",
                appPaths: ["/Applications/Chromium.app"],
                cacheRules: [
                    (
                        .webCache,
                        (home as NSString).appendingPathComponent("Library/Caches/Chromium"),
                        "Chromium Web Önbelleği",
                        "Açık kaynak Chromium önbelleği."
                    )
                ]
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
            
            guard let appPath = installedPath else {
                continue
            }
            
            // 2. Çalışma durumunu denetle
            let isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: spec.bundleId).isEmpty
            
            // 3. Alt kategorileri tara
            var subItems: [BrowserSubItem] = []
            
            // Standart kural taraması
            for rule in spec.cacheRules {
                if fm.fileExists(atPath: rule.subPath) {
                    let size = FastScanner.shared.getPathSize(path: rule.subPath)
                    if size > 1_000 { // 1 KB üstü
                        subItems.append(BrowserSubItem(
                            type: rule.type,
                            name: rule.name,
                            path: rule.subPath,
                            size: size,
                            isSelected: rule.type.defaultSelected,
                            descriptionText: rule.desc
                        ))
                    }
                }
            }
            
            // Firefox özel profil derin taraması (storage/default, favicons, crash logs vb.)
            if spec.bundleId.contains("firefox") || spec.bundleId.contains("mozilla") {
                let profilesDir = (home as NSString).appendingPathComponent("Library/Application Support/Firefox/Profiles")
                if let profiles = try? fm.contentsOfDirectory(atPath: profilesDir) {
                    for profileName in profiles {
                        let profilePath = (profilesDir as NSString).appendingPathComponent(profileName)
                        
                        // Storage / IndexedDB / Web Cache
                        let storagePath = (profilePath as NSString).appendingPathComponent("storage/default")
                        if fm.fileExists(atPath: storagePath) {
                            let sz = FastScanner.shared.getPathSize(path: storagePath)
                            if sz > 10_000 {
                                subItems.append(BrowserSubItem(
                                    type: .webCache,
                                    name: "Firefox Çevrimdışı Web & Depolama (\(profileName.prefix(8)))",
                                    path: storagePath,
                                    size: sz,
                                    isSelected: true,
                                    descriptionText: "Web sitelerinin depoladığı çevrimdışı önbellekler ve IndexedDB verileri."
                                ))
                            }
                        }
                        
                        // Favicons
                        let favPath = (profilePath as NSString).appendingPathComponent("favicons.sqlite")
                        if fm.fileExists(atPath: favPath) {
                            let sz = FastScanner.shared.getPathSize(path: favPath)
                            if sz > 1_000 {
                                subItems.append(BrowserSubItem(
                                    type: .favicons,
                                    name: "Firefox Site Simgeleri (\(profileName.prefix(8)))",
                                    path: favPath,
                                    size: sz,
                                    isSelected: true,
                                    descriptionText: "Yer imleri ve geçmiş sitelerin favicon veritabanı."
                                ))
                            }
                        }
                        
                        // Crash / Minidumps
                        let crashPath = (profilePath as NSString).appendingPathComponent("crashes")
                        if fm.fileExists(atPath: crashPath) {
                            let sz = FastScanner.shared.getPathSize(path: crashPath)
                            if sz > 1_000 {
                                subItems.append(BrowserSubItem(
                                    type: .crashLogs,
                                    name: "Firefox Çökme Raporları",
                                    path: crashPath,
                                    size: sz,
                                    isSelected: true,
                                    descriptionText: "Eski çökme ve hata teşhis günlükleri."
                                ))
                            }
                        }
                        
                        // History (places.sqlite)
                        let placesPath = (profilePath as NSString).appendingPathComponent("places.sqlite")
                        if fm.fileExists(atPath: placesPath) {
                            let sz = FastScanner.shared.getPathSize(path: placesPath)
                            if sz > 1_000 {
                                subItems.append(BrowserSubItem(
                                    type: .history,
                                    name: "Firefox Tarama Geçmişi",
                                    path: placesPath,
                                    size: sz,
                                    isSelected: false,
                                    descriptionText: "Geçmişte ziyaret edilen web sayfaları listesi."
                                ))
                            }
                        }
                    }
                }
            }
            
            // Eğer tarayıcı kuruluysa ama önbellekler temizse bile tarayıcıyı listede tertemiz olarak göster
            if subItems.isEmpty {
                subItems.append(BrowserSubItem(
                    type: .webCache,
                    name: "Genel Web Önbelleği",
                    path: spec.cacheRules.first?.subPath ?? appPath,
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
                    }
                    freed += item.size
                } catch {}
            }
        }
        
        return freed
    }
}
