import Foundation
import AppKit

public enum AppUpdateSource: String, Sendable {
    case sparkle = "Sparkle Feed"
    case homebrew = "Homebrew Cask"
    case direct = "Doğrudan İndirme"
}

public struct AppUpdateItem: Identifiable, Sendable {
    public let id: String
    public let appName: String
    public let bundleId: String
    public let appPath: String
    public let currentVersion: String
    public let latestVersion: String
    public let releaseNotesUrl: String?
    public let downloadUrl: String?
    public let feedUrl: String?
    public let source: AppUpdateSource
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        appName: String,
        bundleId: String,
        appPath: String,
        currentVersion: String,
        latestVersion: String,
        releaseNotesUrl: String? = nil,
        downloadUrl: String? = nil,
        feedUrl: String? = nil,
        source: AppUpdateSource = .sparkle,
        isSelected: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseNotesUrl = releaseNotesUrl
        self.downloadUrl = downloadUrl
        self.feedUrl = feedUrl
        self.source = source
        self.isSelected = isSelected
    }
}

public final class AppUpdaterEngine: @unchecked Sendable {
    public static let shared = AppUpdaterEngine()
    
    private init() {}
    
    /// Yüklü tüm uygulamaları tarayıp Sparkle veya Homebrew üzerinden mevcut güncellemeleri tespit eder
    public func scanAvailableUpdates() async -> (updates: [AppUpdateItem], totalAppsCount: Int) {
        let appDirs = [
            "/Applications",
            "/Applications/Utilities",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]
        
        var totalCount = 0
        var appsWithFeeds: [(name: String, bundleId: String, path: String, currentVer: String, feedUrl: String)] = []
        
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                if item.hasPrefix(".") { continue }
                totalCount += 1
                let appPath = (dir as NSString).appendingPathComponent(item)
                let rawName = (item as NSString).deletingPathExtension
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                
                guard let dict = NSDictionary(contentsOfFile: plistPath) else { continue }
                let bundleId = (dict["CFBundleIdentifier"] as? String) ?? ""
                let currentVer = (dict["CFBundleShortVersionString"] as? String) ?? (dict["CFBundleVersion"] as? String) ?? "1.0"
                let displayName = (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String) ?? rawName
                
                if let feed = dict["SUFeedURL"] as? String, !feed.isEmpty {
                    appsWithFeeds.append((displayName, bundleId, appPath, currentVer, feed))
                }
            }
        }
        
        var discoveredUpdates: [AppUpdateItem] = []
        
        // 1. Sparkle appcast beslemelerini eşzamanlı sorgula (Maksimum 4 saniye zaman aşımı)
        await withTaskGroup(of: AppUpdateItem?.self) { group in
            for app in appsWithFeeds {
                group.addTask {
                    await self.checkSparkleFeed(app: app)
                }
            }
            
            for await item in group {
                if let item = item {
                    discoveredUpdates.append(item)
                }
            }
        }
        
        // 2. Homebrew Cask kontrolü (Eğer sistemde brew varsa)
        let brewUpdates = await checkHomebrewOutdatedCasks()
        for bUpdate in brewUpdates {
            // Eğer Sparkle ile zaten bulunmadıysa ekle
            if !discoveredUpdates.contains(where: { $0.appName.localizedCaseInsensitiveContains(bUpdate.appName) || $0.bundleId == bUpdate.bundleId }) {
                discoveredUpdates.append(bUpdate)
            }
        }
        
        // İsme göre sırala
        discoveredUpdates.sort { $0.appName.localizedCompare($1.appName) == .orderedAscending }
        return (discoveredUpdates, totalCount)
    }
    
    /// Sparkle XML appcast beslemesini okur ve yeni sürüm olup olmadığını denetler
    private func checkSparkleFeed(app: (name: String, bundleId: String, path: String, currentVer: String, feedUrl: String)) async -> AppUpdateItem? {
        guard let url = URL(string: app.feedUrl) else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue("Sparkle/1.27.1 IhyaMac/1.2", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...399).contains(httpResponse.statusCode) else {
                return nil
            }
            
            guard let xmlString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return nil
            }
            
            // İlk geçerli <item> bloğunu bul
            guard let itemRange = xmlString.range(of: "<item>", options: .caseInsensitive),
                  let itemEndRange = xmlString.range(of: "</item>", options: .caseInsensitive, range: itemRange.upperBound..<xmlString.endIndex) else {
                return nil
            }
            
            let itemContent = String(xmlString[itemRange.upperBound..<itemEndRange.lowerBound])
            
            // Sürüm bilgisini ayıkla: sparkle:shortVersionString="..." veya <sparkle:shortVersionString>...</sparkle:shortVersionString> veya <title>...</title>
            var latestVersion: String? = nil
            
            if let verAttrRange = itemContent.range(of: "sparkle:shortVersionString=\"") {
                let after = itemContent[verAttrRange.upperBound...]
                if let endQuote = after.firstIndex(of: "\"") {
                    latestVersion = String(after[..<endQuote])
                }
            }
            
            if latestVersion == nil, let verTagRange = itemContent.range(of: "<sparkle:shortVersionString>") {
                let after = itemContent[verTagRange.upperBound...]
                if let endTag = after.range(of: "</sparkle:shortVersionString>") {
                    latestVersion = String(after[..<endTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if latestVersion == nil, let titleRange = itemContent.range(of: "<title>") {
                let after = itemContent[titleRange.upperBound...]
                if let endTag = after.range(of: "</title>") {
                    let titleStr = String(after[..<endTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    // Başlıkta sürüm numarası varsa (örn. 5.2.0 veya v33.0.0)
                    let clean = titleStr.replacingOccurrences(of: "v", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                    if clean.contains(".") {
                        latestVersion = clean
                    }
                }
            }
            
            guard let newVersion = latestVersion, !newVersion.isEmpty else { return nil }
            
            // Sürüm karşılaştırması: Yeni sürüm mevcut sürümden büyük mü?
            let isNewer = isVersion(newVersion, newerThan: app.currentVer)
            guard isNewer else { return nil }
            
            // İndirme URL'si (enclosure url)
            var downloadUrl: String? = nil
            if let encRange = itemContent.range(of: "enclosure url=\"") {
                let after = itemContent[encRange.upperBound...]
                if let endQuote = after.firstIndex(of: "\"") {
                    downloadUrl = String(after[..<endQuote])
                }
            }
            
            // Değişiklik notları linki
            var releaseNotesUrl: String? = nil
            if let relRange = itemContent.range(of: "<sparkle:releaseNotesLink>") {
                let after = itemContent[relRange.upperBound...]
                if let endTag = after.range(of: "</sparkle:releaseNotesLink>") {
                    releaseNotesUrl = String(after[..<endTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            return AppUpdateItem(
                appName: app.name,
                bundleId: app.bundleId,
                appPath: app.path,
                currentVersion: app.currentVer,
                latestVersion: newVersion,
                releaseNotesUrl: releaseNotesUrl,
                downloadUrl: downloadUrl,
                feedUrl: app.feedUrl,
                source: .sparkle,
                isSelected: true
            )
        } catch {
            return nil
        }
    }
    
    /// Homebrew üzerinden kurulu ve eski kalmış uygulamaları tarar
    private func checkHomebrewOutdatedCasks() async -> [AppUpdateItem] {
        guard FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ||
              FileManager.default.fileExists(atPath: "/usr/local/bin/brew") else {
            return []
        }
        
        let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ? "/opt/homebrew/bin/brew" : "/usr/local/bin/brew"
        
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brewPath)
            process.arguments = ["outdated", "--cask", "--json=v2"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let casks = json["casks"] as? [[String: Any]] else {
                    return []
                }
                
                var items: [AppUpdateItem] = []
                for cask in casks {
                    guard let name = cask["name"] as? String,
                          let currentVer = (cask["installed_versions"] as? [String])?.first,
                          let latestVer = cask["current_version"] as? String else {
                        continue
                    }
                    
                    let cleanName = name.capitalized.replacingOccurrences(of: "-", with: " ")
                    items.append(AppUpdateItem(
                        appName: cleanName,
                        bundleId: "homebrew.cask.\(name)",
                        appPath: "/Applications/\(cleanName).app",
                        currentVersion: currentVer,
                        latestVersion: latestVer,
                        downloadUrl: nil,
                        feedUrl: nil,
                        source: .homebrew,
                        isSelected: true
                    ))
                }
                return items
            } catch {
                return []
            }
        }.value
    }
    
    /// Sürüm dizgilerini numerik karşılaştırır (örn. 5.2.0 > 4.3.4)
    public func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let clean1 = v1.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        let clean2 = v2.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        
        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
    
    /// Tek tıklamayla güncellemeyi başlatır (İndirme linkini açar veya DMG'yi indirir)
    public func openUpdate(for item: AppUpdateItem) {
        if let dl = item.downloadUrl, let url = URL(string: dl) {
            NSWorkspace.shared.open(url)
            return
        }
        if let rel = item.releaseNotesUrl, let url = URL(string: rel) {
            NSWorkspace.shared.open(url)
            return
        }
        // Eğer indirme linki yoksa resmi web sitesi veya arama
        let query = "\(item.appName) mac download".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://google.com/search?q=\(query)") {
            NSWorkspace.shared.open(url)
        }
    }
}
