import Foundation
import AppKit

@MainActor
public final class IhyaUpdateChecker: ObservableObject {
    public static let shared = IhyaUpdateChecker()
    
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var downloadURL: URL? = nil
    @Published public var isChecking: Bool = false
    @Published public var isUpdating: Bool = false
    @Published public var updateStatusText: String = ""
    @Published public var lastCheckDate: Date? = nil
    @Published public var checkCompletedMessage: String? = nil
    
    private var periodicTimer: Timer?
    
    public let currentVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.5.0"
    }()
    
    // Can Eser Central Update Feed (no rate limits)
    private let centralAPI = URL(string: "https://caneser.com/api/ihya/version.json")
    
    private init() {}
    
    public func startPeriodicChecks(interval: TimeInterval = 3600 * 2) {
        // Run first check 3 seconds after launch for smooth startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.checkForUpdates(silent: true)
        }
        
        periodicTimer?.invalidate()
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForUpdates(silent: true)
            }
        }
    }
    
    public func checkForUpdates(silent: Bool = true) {
        guard !isChecking && !isUpdating else { return }
        isChecking = true
        checkCompletedMessage = nil
        
        Task {
            defer {
                self.isChecking = false
                self.lastCheckDate = Date()
            }
            
            if let centralURL = centralAPI, let info = await checkCentralAPI(url: centralURL) {
                applyUpdateInfo(info, silent: silent)
                return
            }
            
            if !silent {
                self.checkCompletedMessage = "İhyâ güncel (v\(self.currentVersion))"
            }
        }
    }
    
    private struct UpdateInfo {
        let version: String
        let notes: String
        let url: URL?
    }
    
    private func checkCentralAPI(url: URL) async -> UpdateInfo? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        req.cachePolicy = .reloadIgnoringLocalCacheData
        
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else {
            return nil
        }
        
        let notes = json["notes"] as? String ?? ""
        let dlStr = json["download_url"] as? String ?? "https://caneser.com/downloads/Ihya.dmg"
        return UpdateInfo(version: version, notes: notes, url: URL(string: dlStr))
    }
    
    private func applyUpdateInfo(_ info: UpdateInfo, silent: Bool) {
        self.latestVersion = info.version
        self.releaseNotes = info.notes
        self.downloadURL = info.url
        
        if isVersionNewer(info.version, than: currentVersion) {
            self.updateAvailable = true
            self.checkCompletedMessage = nil
        } else {
            self.updateAvailable = false
            self.checkCompletedMessage = "İhyâ en güncel sürümde (v\(currentVersion))"
        }
    }
    
    // MARK: - Direct Automated In-App Update
    public func performDirectAutoUpdate() {
        guard let targetURL = downloadURL ?? URL(string: "https://caneser.com/downloads/Ihya.dmg") else { return }
        
        self.isUpdating = true
        self.updateStatusText = "İhyâ v\(latestVersion) indiriliyor..."
        
        Task.detached(priority: .userInitiated) {
            do {
                let (tempLocation, _) = try await URLSession.shared.download(from: targetURL)
                let uniqueId = UUID().uuidString.prefix(8)
                let destinationURL = URL(fileURLWithPath: "/tmp/Ihya_Update_\(uniqueId).dmg")
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
                
                await MainActor.run {
                    self.updateStatusText = "Paket kuruluyor ve yeniden başlatılıyor..."
                }
                
                let currentPid = ProcessInfo.processInfo.processIdentifier
                let currentBundle = Bundle.main.bundlePath
                let targetAppPath = (currentBundle.hasSuffix(".app") && !currentBundle.contains("/.build/") && !currentBundle.contains("/DerivedData/")) ? currentBundle : "/Applications/İhyâ.app"
                
                let scriptContent = """
                #!/bin/bash
                exec </dev/null
                exec >/tmp/ihya_update.log 2>&1

                echo "=== İhyâ Otomatik Güncelleme Başlatıldı ==="
                echo "Tarih: $(date)"
                DEST_DMG="\(destinationURL.path)"
                TARGET_APP="\(targetAppPath)"
                CURRENT_PID=\(currentPid)

                echo "1. Hedef DMG: $DEST_DMG"
                echo "2. Hedef Uygulama Yolu: $TARGET_APP"
                echo "3. Eski İhyâ PID: $CURRENT_PID"

                # Benzersiz mount dizini oluştur
                MOUNT_DIR=$(mktemp -d /tmp/ihya_mount_XXXXXX)
                echo "4. Geçici Mount Noktası: $MOUNT_DIR"

                cleanup() {
                    echo "Temizlik yapılıyor..."
                    /usr/bin/hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
                    diskutil eject "$MOUNT_DIR" 2>/dev/null || true
                    rm -rf "$MOUNT_DIR"
                    rm -f "$DEST_DMG"
                    rm -f /tmp/ihya_apply_update.sh
                }
                trap cleanup EXIT

                # DMG'yi bağla
                echo "5. DMG bağlanıyor..."
                if ! /usr/bin/hdiutil attach "$DEST_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -noverify -noautoopen; then
                    echo "HATA: DMG bağlanamadı!"
                    exit 1
                fi

                # Mount edilen DMG içindeki .app paketini bul
                APP_SOURCE=$(find "$MOUNT_DIR" -maxdepth 2 -name "*.app" | head -n 1)

                if [ -z "$APP_SOURCE" ] || [ ! -d "$APP_SOURCE" ]; then
                    echo "HATA: DMG içinde geçerli .app bulunamadı!"
                    exit 1
                fi

                echo "6. Bulunan kaynak paket: $APP_SOURCE"

                # Eski İhyâ sürecini sonlandır
                echo "7. Eski İhyâ süreci sonlandırılıyor (PID: $CURRENT_PID)..."
                kill $CURRENT_PID 2>/dev/null || true
                for i in {1..15}; do
                    if ! kill -0 $CURRENT_PID 2>/dev/null; then
                        break
                    fi
                    sleep 0.2
                done
                kill -9 $CURRENT_PID 2>/dev/null || true
                killall -9 IhyaApp 2>/dev/null || true
                sleep 0.3

                # Atomik kurulum yap
                echo "8. Yeni sürüm kuruluyor..."
                BACKUP_TMP="/tmp/Ihya_Backup_$$"
                rm -rf "$BACKUP_TMP"

                if [ -d "$TARGET_APP" ]; then
                    mv "$TARGET_APP" "$BACKUP_TMP" 2>/dev/null || rm -rf "$TARGET_APP"
                fi

                if ! cp -R "$APP_SOURCE" "$TARGET_APP"; then
                    echo "HATA: Yeni uygulama kopyalanamadı, yedek geri yükleniyor..."
                    if [ -d "$BACKUP_TMP" ]; then
                        mv "$BACKUP_TMP" "$TARGET_APP" 2>/dev/null || true
                    fi
                    exit 1
                fi

                rm -rf "$BACKUP_TMP" 2>/dev/null || true

                # Karantina kaldır
                echo "9. Güvenlik izinleri tanzim ediliyor..."
                xattr -rd com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

                # DMG çöz
                echo "10. DMG çözülüyor..."
                for i in {1..5}; do
                    if /usr/bin/hdiutil detach "$MOUNT_DIR" -force 2>/dev/null; then
                        break
                    fi
                    diskutil eject "$MOUNT_DIR" 2>/dev/null || true
                    sleep 0.4
                done

                # Güncellenen yeni İhyâ'yı başlat
                echo "11. Güncellenen yeni sürüm başlatılıyor..."
                sleep 0.5
                /usr/bin/open "$TARGET_APP"

                echo "=== İhyâ Güncellemesi Başarıyla Tamamlandı ==="
                """
                
                let scriptPath = "/tmp/ihya_apply_update.sh"
                try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
                
                let chmodProc = Process()
                chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmodProc.arguments = ["+x", scriptPath]
                try chmodProc.run()
                chmodProc.waitUntilExit()
                
                let updateProc = Process()
                updateProc.executableURL = URL(fileURLWithPath: "/bin/bash")
                updateProc.arguments = ["-c", "nohup /tmp/ihya_apply_update.sh >/dev/null 2>&1 &"]
                try updateProc.run()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run {
                    self.isUpdating = false
                    self.updateStatusText = "Güncelleme indirilemedi."
                    
                    let alert = NSAlert()
                    alert.messageText = "Otomatik Güncelleme Tamamlanamadı"
                    alert.informativeText = "İnternet bağlantınızı kontrol ediniz. Dilerseniz web sitesinden manuel indirebilirsiniz.\n\nHata: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Tamam")
                    alert.addButton(withTitle: "Manuel İndir")
                    let resp = alert.runModal()
                    if resp == .alertSecondButtonReturn {
                        self.openReleasePage()
                    }
                }
            }
        }
    }
    
    public func openReleasePage() {
        if let url = downloadURL ?? URL(string: "https://caneser.com/downloads/Ihya.dmg") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func isVersionNewer(_ v1: String, than v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedDescending
    }
}
