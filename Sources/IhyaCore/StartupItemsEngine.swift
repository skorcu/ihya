import Foundation
import AppKit

public enum StartupItemType: String, CaseIterable, Sendable, Codable {
    case loginItem = "Giriş Öğesi"
    case launchAgent = "Kullanıcı Servisi"
    case launchDaemon = "Sistem Servisi"
}

public struct StartupItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let path: String
    public let type: StartupItemType
    public var isEnabled: Bool
    public let isBroken: Bool
    public let vendor: String
    public let plistPath: String?
    public let rawArgs: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        type: StartupItemType,
        isEnabled: Bool,
        isBroken: Bool,
        vendor: String,
        plistPath: String? = nil,
        rawArgs: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.isEnabled = isEnabled
        self.isBroken = isBroken
        self.vendor = vendor
        self.plistPath = plistPath
        self.rawArgs = rawArgs
    }
}

public final class StartupItemsEngine: ObservableObject, @unchecked Sendable {
    public static let shared = StartupItemsEngine()
    
    @Published public var items: [StartupItem] = []
    @Published public var isLoading: Bool = false
    @Published public var lastScanDate: Date? = nil
    @Published public var brokenCount: Int = 0
    
    private let disabledLoginItemsKey = "ihya_disabled_login_items_v1"
    
    public init() {}
    
    // MARK: - 1. Tüm Başlangıç Öğelerini Tara
    public func scanAllItems() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        var results: [StartupItem] = []
        
        // A) Giriş Öğeleri (System Events Login Items)
        let loginItems = fetchLoginItems()
        results.append(contentsOf: loginItems)
        
        // B) Kullanıcı LaunchAgents (~/Library/LaunchAgents)
        let home = NSHomeDirectory()
        let userAgentsDir = (home as NSString).appendingPathComponent("Library/LaunchAgents")
        let userAgents = scanLaunchAgentsDirectory(dirPath: userAgentsDir, type: .launchAgent)
        results.append(contentsOf: userAgents)
        
        // C) Sistem LaunchAgents (/Library/LaunchAgents)
        let sysAgents = scanLaunchAgentsDirectory(dirPath: "/Library/LaunchAgents", type: .launchDaemon)
        results.append(contentsOf: sysAgents)
        
        let countBroken = results.filter { $0.isBroken }.count
        
        await MainActor.run {
            self.items = results
            self.brokenCount = countBroken
            self.isLoading = false
            self.lastScanDate = Date()
        }
    }
    
    // MARK: - 2. Login Items Taraması
    private func fetchLoginItems() -> [StartupItem] {
        var list: [StartupItem] = []
        let script = """
        tell application "System Events"
            set out to ""
            repeat with anItem in every login item
                set n to name of anItem
                set p to path of anItem
                set out to out & n & "<SEP>" & p & "\\n"
            end repeat
            return out
        end tell
        """
        
        var activeNames = Set<String>()
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let output = appleScript.executeAndReturnError(&error)
            if let str = output.stringValue {
                let lines = str.components(separatedBy: "\n")
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    let parts = line.components(separatedBy: "<SEP>")
                    guard parts.count >= 2 else { continue }
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let path = parts[1].trimmingCharacters(in: .whitespaces)
                    
                    activeNames.insert(name)
                    
                    let isBroken = path == "missing value" || path.isEmpty || !FileManager.default.fileExists(atPath: path)
                    let vendor = detectVendor(name: name, path: path)
                    
                    list.append(StartupItem(
                        name: name,
                        path: path,
                        type: .loginItem,
                        isEnabled: true,
                        isBroken: isBroken,
                        vendor: vendor,
                        plistPath: nil
                    ))
                }
            }
        }
        
        // Kullanıcı daha önce İhyâ içinden bir Login Item'ı devre dışı bıraktıysa:
        if let disabledDict = UserDefaults.standard.dictionary(forKey: disabledLoginItemsKey) as? [String: String] {
            for (name, path) in disabledDict where !activeNames.contains(name) {
                let isBroken = path == "missing value" || path.isEmpty || !FileManager.default.fileExists(atPath: path)
                let vendor = detectVendor(name: name, path: path)
                list.append(StartupItem(
                    name: name,
                    path: path,
                    type: .loginItem,
                    isEnabled: false,
                    isBroken: isBroken,
                    vendor: vendor,
                    plistPath: nil
                ))
            }
        }
        
        return list
    }
    
    // MARK: - 3. LaunchAgents Dizin Taraması
    private func scanLaunchAgentsDirectory(dirPath: String, type: StartupItemType) -> [StartupItem] {
        var list: [StartupItem] = []
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { return [] }
        
        for file in files {
            let isPlist = file.hasSuffix(".plist")
            let isDisabledPlist = file.hasSuffix(".plist.disabled")
            guard isPlist || isDisabledPlist else { continue }
            
            let fullPlistPath = (dirPath as NSString).appendingPathComponent(file)
            guard let dict = NSDictionary(contentsOfFile: fullPlistPath) else { continue }
            
            let label = (dict["Label"] as? String) ?? file.replacingOccurrences(of: ".plist.disabled", with: "").replacingOccurrences(of: ".plist", with: "")
            
            var binaryPath: String? = dict["Program"] as? String
            var rawArgsStr: String? = nil
            if let args = dict["ProgramArguments"] as? [String], !args.isEmpty {
                if binaryPath == nil {
                    binaryPath = args[0]
                }
                rawArgsStr = args.joined(separator: " ")
            }
            
            let targetPath = binaryPath ?? ""
            let isBroken: Bool
            if targetPath.isEmpty {
                isBroken = true
            } else {
                isBroken = !FileManager.default.fileExists(atPath: targetPath)
            }
            
            // Sistem Apple dahili ajanlarını filtrele (kritik sistem dosyalarına dokunulmaz)
            if targetPath.hasPrefix("/System") || targetPath.hasPrefix("/usr/libexec") {
                continue
            }
            
            let friendlyName = cleanDaemonName(label: label, file: file)
            let vendor = detectVendor(name: friendlyName, path: targetPath, label: label)
            let isEnabled = isPlist && (dict["RunAtLoad"] as? Bool != false)
            
            list.append(StartupItem(
                name: friendlyName,
                path: targetPath,
                type: type,
                isEnabled: isEnabled,
                isBroken: isBroken,
                vendor: vendor,
                plistPath: fullPlistPath,
                rawArgs: rawArgsStr
            ))
        }
        
        return list
    }
    
    // MARK: - 4. Açma / Kapama (Toggle) Eylemi
    public func toggleItem(_ item: StartupItem) async -> Bool {
        if item.type == .loginItem {
            return await toggleLoginItem(item)
        } else {
            return await toggleLaunchAgent(item)
        }
    }
    
    private func toggleLoginItem(_ item: StartupItem) async -> Bool {
        if item.isEnabled {
            // Devre dışı bırak: System Events'ten sil ve İhyâ hafızasına kaydet
            let script = """
            tell application "System Events"
                delete (every login item whose name is "\(item.name)")
            end tell
            """
            var err: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&err)
            }
            
            var disabledDict = UserDefaults.standard.dictionary(forKey: disabledLoginItemsKey) as? [String: String] ?? [:]
            disabledDict[item.name] = item.path
            UserDefaults.standard.set(disabledDict, forKey: disabledLoginItemsKey)
        } else {
            // Etkinleştir: System Events'e yeniden ekle ve İhyâ hafızasından kaldır
            if !item.path.isEmpty && item.path != "missing value" && FileManager.default.fileExists(atPath: item.path) {
                let script = """
                tell application "System Events"
                    make new login item at end with properties {path:"\(item.path)", hidden:false}
                end tell
                """
                var err: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(&err)
                }
            }
            
            var disabledDict = UserDefaults.standard.dictionary(forKey: disabledLoginItemsKey) as? [String: String] ?? [:]
            disabledDict.removeValue(forKey: item.name)
            UserDefaults.standard.set(disabledDict, forKey: disabledLoginItemsKey)
        }
        
        await scanAllItems()
        return true
    }
    
    private func toggleLaunchAgent(_ item: StartupItem) async -> Bool {
        guard let plistPath = item.plistPath else { return false }
        let fm = FileManager.default
        
        if item.isEnabled {
            // Devre Dışı Bırak: .plist -> .plist.disabled
            let newPath = plistPath.replacingOccurrences(of: ".plist", with: ".plist.disabled")
            do {
                _ = shell("launchctl unload \"\(plistPath)\" 2>/dev/null || true")
                try fm.moveItem(atPath: plistPath, toPath: newPath)
            } catch {
                return false
            }
        } else {
            // Etkinleştir: .plist.disabled -> .plist
            let newPath = plistPath.replacingOccurrences(of: ".plist.disabled", with: ".plist")
            do {
                try fm.moveItem(atPath: plistPath, toPath: newPath)
                _ = shell("launchctl load \"\(newPath)\" 2>/dev/null || true")
            } catch {
                return false
            }
        }
        
        await scanAllItems()
        return true
    }
    
    // MARK: - 5. Öğeyi Tamamen Kaldır (Sil)
    public func removeItem(_ item: StartupItem) async -> Bool {
        if item.type == .loginItem {
            let script = """
            tell application "System Events"
                delete (every login item whose name is "\(item.name)")
            end tell
            """
            var err: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&err)
            }
            var disabledDict = UserDefaults.standard.dictionary(forKey: disabledLoginItemsKey) as? [String: String] ?? [:]
            disabledDict.removeValue(forKey: item.name)
            UserDefaults.standard.set(disabledDict, forKey: disabledLoginItemsKey)
        } else if let plistPath = item.plistPath {
            _ = shell("launchctl unload \"\(plistPath)\" 2>/dev/null || true")
            try? FileManager.default.trashItem(at: URL(fileURLWithPath: plistPath), resultingItemURL: nil)
        }
        
        await scanAllItems()
        return true
    }
    
    // MARK: - 6. Kırık / Ölü Kayıtları Tek Hamlede Temizle
    public func cleanAllBroken() async -> Int {
        let broken = items.filter { $0.isBroken }
        var cleanedCount = 0
        for item in broken {
            if await removeItem(item) {
                cleanedCount += 1
            }
        }
        return cleanedCount
    }
    
    // MARK: - Yardımcı Metodlar (Geliştirici & İsim Tespiti)
    private func cleanDaemonName(label: String, file: String) -> String {
        var clean = label
        for prefix in ["com.apple.", "com.google.", "com.adobe.", "sh.brew.", "homebrew.mxcl."] {
            if clean.hasPrefix(prefix) {
                clean = String(clean.dropFirst(prefix.count))
            }
        }
        if clean.isEmpty {
            clean = file.replacingOccurrences(of: ".plist", with: "").replacingOccurrences(of: ".disabled", with: "")
        }
        return clean.capitalized
    }
    
    private func detectVendor(name: String, path: String, label: String = "") -> String {
        let text = "\(name) \(path) \(label)".lowercased()
        if text.contains("google") { return "Google LLC" }
        if text.contains("adobe") { return "Adobe Systems" }
        if text.contains("brew") || text.contains("postgresql") || text.contains("mongodb") { return "Homebrew Servisi" }
        if text.contains("sarkacadam") { return "Sarkaç Adam" }
        if text.contains("kasif") || text.contains("kâşif") { return "Kâşif Motoru" }
        if text.contains("zoom") { return "Zoom Video" }
        if text.contains("anydesk") { return "AnyDesk Software" }
        if text.contains("epson") { return "Seiko Epson" }
        if text.contains("steam") || text.contains("valve") { return "Valve Corporation" }
        if text.contains("betterdisplay") || text.contains("waydabber") { return "Waydabber" }
        if text.contains("microsoft") { return "Microsoft Corporation" }
        return "Üçüncü Parti Uygulama"
    }
    
    @discardableResult
    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
