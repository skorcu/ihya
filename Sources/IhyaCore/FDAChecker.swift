import Foundation
import AppKit
import Darwin

public final class FDAChecker: @unchecked Sendable {
    public static let shared = FDAChecker()
    
    private init() {}
    
    /// macOS Tam Disk Erişimi (Full Disk Access) izninin verilip verilmediğini doğrular.
    public static func hasFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        
        // 1. Korumalı sistem ve kullanıcı dosyalarını doğrudan açmayı dene (POSIX O_RDONLY)
        let testPaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Application Support/com.apple.TCC",
            home + "/Library/Safari/Bookmarks.plist",
            home + "/Library/Safari",
            home + "/Library/Suggestions",
            home + "/Library/PersonalizationPortrait",
            home + "/Library/Mail"
        ]
        
        for path in testPaths {
            let fd = open(path, O_RDONLY)
            if fd >= 0 {
                close(fd)
                return true
            }
        }
        
        // 2. Korumalı dizinlerde opendir testi
        let dirPaths = [
            home + "/Library/Safari",
            home + "/Library/Suggestions",
            home + "/Library/PersonalizationPortrait"
        ]
        for dp in dirPaths {
            if let dir = opendir(dp) {
                closedir(dir)
                return true
            }
        }
        
        return false
    }
    
    /// macOS TCC (Transparency, Consent, and Control) alt sistemine korumalı yol erişim
    /// çağrısı yaparak uygulamanın Sistem Ayarları > Tam Disk Erişimi listesine kaydedilmesini tetikler.
    public static func triggerTCCRegistration() {
        let home = NSHomeDirectory()
        let probePaths = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            home + "/Library/Safari/Bookmarks.plist",
            home + "/Library/Mail",
            home + "/Library/Suggestions",
            home + "/Library/PersonalizationPortrait"
        ]
        
        for path in probePaths {
            let fd = open(path, O_RDONLY)
            if fd >= 0 {
                close(fd)
            }
        }
    }
    
    /// macOS Sistem Ayarları'nı doğrudan Gizlilik & Güvenlik > Tam Disk Erişimi sekmesinde açar.
    public static func openSystemSettings() {
        triggerTCCRegistration()
        
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// macOS Sistem Ayarları'nı doğrudan Gizlilik & Güvenlik > Uygulama Yönetimi sekmesinde açar.
    public static func openAppManagementSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// İhyâ uygulamasını Finder'da bizzat seçili olarak öne getirir (Sistem Ayarları'na sürükle-bırak için).
    public static func revealInFinder() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }
    
    /// Uygulamanın /Applications veya ~/Applications dizininde kurulu olup olmadığını denetler.
    public static func isInstalledInApplications() -> Bool {
        let path = Bundle.main.bundlePath
        let userApps = (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        return path.hasPrefix("/Applications") || path.hasPrefix(userApps)
    }
}
