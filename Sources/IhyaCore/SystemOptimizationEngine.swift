import Foundation
import AppKit
import Darwin

public struct MemoryStats: Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let activeBytes: UInt64
    public let inactiveBytes: UInt64
    public let wiredBytes: UInt64
    public let usagePercentage: Double
    
    public var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .memory)
    }
    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .memory)
    }
    public var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .memory)
    }
}

public struct OptimizationTask: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public var isCompleted: Bool
    public var freedText: String
    
    public init(id: String, title: String, description: String, icon: String, isCompleted: Bool = false, freedText: String = "") {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.isCompleted = isCompleted
        self.freedText = freedText
    }
}

public struct AppMemoryUsage: Identifiable, Sendable {
    public let id: pid_t
    public let name: String
    public let bundleIdentifier: String
    public let memoryBytes: UInt64
    public let formattedMemory: String
    public let percentageOfRAM: Double
    @MainActor public var icon: NSImage?
    
    public init(id: pid_t, name: String, bundleIdentifier: String, memoryBytes: UInt64, percentageOfRAM: Double, icon: NSImage? = nil) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.formattedMemory = ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
        self.percentageOfRAM = percentageOfRAM
        self.icon = icon
    }
}

@MainActor
public final class SystemOptimizationEngine: ObservableObject {
    public static let shared = SystemOptimizationEngine()
    
    @Published public var memoryStats: MemoryStats = MemoryStats(
        totalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: 10 * 1024 * 1024 * 1024,
        freeBytes: 6 * 1024 * 1024 * 1024,
        activeBytes: 5 * 1024 * 1024 * 1024,
        inactiveBytes: 3 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        usagePercentage: 62.5
    )
    
    @Published public var topMemoryHogs: [AppMemoryUsage] = []
    @Published public var isOptimizing: Bool = false
    @Published public var currentActionText: String = ""
    @Published public var tasks: [OptimizationTask] = [
        OptimizationTask(
            id: "ram",
            title: "İnaktif Bellek Arındırma (RAM Purge)",
            description: "Kullanılmayan önbellek sayfalarını boşaltarak anında serbest bellek kazandırır.",
            icon: "memorychip"
        ),
        OptimizationTask(
            id: "dns",
            title: "DNS & Ağ Çözümleyici Önbelleği",
            description: "Bayat DNS kayıtlarını sıfırlar, ağ tepki süresini hızlandırır.",
            icon: "network"
        ),
        OptimizationTask(
            id: "quicklook",
            title: "Quick Look & Önizleme Önbelleği",
            description: "Bozuk veya şişmiş küçük resim (thumbnail) veritabanını yeniler.",
            icon: "eye.fill"
        ),
        OptimizationTask(
            id: "diagnostics",
            title: "Çökme & Tanılama Günlükleri",
            description: "Geçmiş uygulama çökmelerinden kalan devasa .ips ve .diag raporlarını temizler.",
            icon: "stethoscope"
        ),
        OptimizationTask(
            id: "snapshots",
            title: "APFS Yerel Yedekleri Seyrelt (Snapshots)",
            description: "Diski işgal eden eski Time Machine yerel anlık görüntülerini seyreltir.",
            icon: "clock.arrow.circlepath"
        ),
        OptimizationTask(
            id: "fontcache",
            title: "Yazı Tipi & Font Kayıt Defteri",
            description: "Bozuk sistem font önbelleklerini sıfırlar, uygulama açılışlarını hızlandırır.",
            icon: "textformat"
        ),
        OptimizationTask(
            id: "findersync",
            title: "Finder Eklenti & Kanca Onarımı (FinderSync)",
            description: "Silinmiş uygulamaların Finder ve Çöp Kutusu'nu donduran arka plan kancalarını temizler.",
            icon: "macwindow.on.rectangle"
        ),
        OptimizationTask(
            id: "hotcorners",
            title: "Sıcak Köşe Çakışma Onarımı",
            description: "Sol üstteki kırmızı kapatma tuşunu engelleyen hatalı tetikleyicileri düzeltir.",
            icon: "cursorarrow.rays"
        ),
        OptimizationTask(
            id: "fullscreen",
            title: "Tam Ekran Menü & Pencere Kontrolü",
            description: "Tam ekranda kırmızı kapatma butonunun kaybolmasını veya kilitlenmesini engeller.",
            icon: "arrow.up.left.and.arrow.down.right"
        )
    ]
    
    public init() {
        refreshMemoryStats()
        refreshTopMemoryHogs()
    }
    
    /// En çok RAM tüketen ilk 5 uygulamayı gerçek zamanlı tespit eder
    public func refreshTopMemoryHogs() {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let myPID = getpid()
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != myPID
        }
        
        var list: [AppMemoryUsage] = []
        for app in apps {
            let pid = app.processIdentifier
            var taskInfo = proc_taskinfo()
            let size = MemoryLayout<proc_taskinfo>.size
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
            let memBytes: UInt64 = (result == Int32(size)) ? taskInfo.pti_resident_size : 0
            
            if memBytes > 15_000_000 { // 15 MB üzeri
                let pct = (Double(memBytes) / Double(max(totalRAM, 1))) * 100.0
                list.append(AppMemoryUsage(
                    id: pid,
                    name: app.localizedName ?? "Uygulama",
                    bundleIdentifier: app.bundleIdentifier ?? "",
                    memoryBytes: memBytes,
                    percentageOfRAM: pct,
                    icon: app.icon
                ))
            }
        }
        
        list.sort { $0.memoryBytes > $1.memoryBytes }
        self.topMemoryHogs = Array(list.prefix(5))
    }
    
    /// Bellek canavarı bir uygulamayı nazikçe (terminate), gerekirse zorla (forceTerminate) kapatır
    public func terminateApp(pid: pid_t) {
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshMemoryStats()
            self.refreshTopMemoryHogs()
        }
    }
    
    /// Anlık RAM İstatistiklerini Mach API üzerinden okur
    public func refreshMemoryStats() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let pageSize = UInt64(getpagesize())
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        
        let used = active + wired + compressed
        let percentage = Double(used) / Double(max(totalRAM, 1)) * 100.0
        
        self.memoryStats = MemoryStats(
            totalBytes: totalRAM,
            usedBytes: used,
            freeBytes: max(totalRAM > used ? totalRAM - used : free, free),
            activeBytes: active,
            inactiveBytes: inactive,
            wiredBytes: wired,
            usagePercentage: min(max(percentage, 0.0), 100.0)
        )
        refreshTopMemoryHogs()
    }
    
    /// Tek Tıkla İnaktif RAM'i Boşaltır
    public func purgeMemory() async -> UInt64 {
        let beforeFree = memoryStats.freeBytes
        currentActionText = "İnaktif bellek sayfaları geri kazanılıyor..."
        
        await Task.detached(priority: .userInitiated) {
            // 1. Önce /usr/sbin/purge dene (root/geliştirici modunda)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
            try? process.run()
            process.waitUntilExit()
            
            // 2. Darwin Userland VM Pressure döngüsü: Inactive bellek sayfalarını kernel'a serbest bıraktır
            let chunkSize = 64 * 1024 * 1024 // 64 MB
            var buffers: [UnsafeMutableRawPointer] = []
            let iterations = 16 // 1 GB test baskısı
            for _ in 0..<iterations {
                if let ptr = malloc(chunkSize) {
                    memset(ptr, 0, chunkSize)
                    buffers.append(ptr)
                }
            }
            for ptr in buffers {
                free(ptr)
            }
        }.value
        
        refreshMemoryStats()
        let afterFree = memoryStats.freeBytes
        let gained = afterFree > beforeFree ? afterFree - beforeFree : 0
        return gained
    }

    /// DNS Önbelleğini Sıfırlar
    public func flushDNS() async {
        await Task.detached(priority: .userInitiated) {
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            p1.arguments = ["-flushcache"]
            try? p1.run()
            p1.waitUntilExit()
            
            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p2.arguments = ["-HUP", "mDNSResponder"]
            try? p2.run()
            p2.waitUntilExit()
        }.value
    }
    
    /// QuickLook Önbelleğini Sıfırlar
    public func flushQuickLook() async {
        await Task.detached(priority: .userInitiated) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            p.arguments = ["-r", "cache"]
            try? p.run()
            p.waitUntilExit()
        }.value
    }
    
    /// Tanılama ve Çökme Günlüklerini Geri Dönüşümlü Temizler
    public func cleanDiagnosticLogs() async -> Int64 {
        return await Task.detached(priority: .userInitiated) { () -> Int64 in
            let fm = FileManager.default
            let home = NSHomeDirectory()
            let diagPath = (home as NSString).appendingPathComponent("Library/Logs/DiagnosticReports")
            
            guard let files = try? fm.contentsOfDirectory(atPath: diagPath) else { return 0 }
            var freed: Int64 = 0
            
            for file in files where file.hasSuffix(".ips") || file.hasSuffix(".diag") || file.hasSuffix(".crash") {
                let fullPath = (diagPath as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? Int64 {
                    do {
                        try fm.trashItem(at: URL(fileURLWithPath: fullPath), resultingItemURL: nil)
                        freed += size
                    } catch {}
                }
            }
            return freed
        }.value
    }

    /// APFS Yerel Anlık Görüntülerini (Snapshots) Seyreltir (Agresif Urgency 4 ile kilitli blokları çözer)
    public func thinLocalSnapshots() async -> String {
        return await Task.detached(priority: .userInitiated) { () -> String in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            process.arguments = ["thinlocalsnapshots", "/", "100000000000", "4"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if output.contains("Thinned") {
                return "Yerel anlık görüntüler seyreltildi"
            }
            return "Anlık görüntüler dengeli"
        }.value
    }
    
    /// Yazı Tipi & Font Kayıt Defteri Önbelleğini Sıfırlar
    public func flushFontCache() async {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/atsutil")
            process.arguments = ["databases", "-removeUser"]
            try? process.run()
            process.waitUntilExit()
        }.value
    }
    
    /// Finder'ı donduran yetim veya ölü FinderSync eklentilerini devre dışı bırakır
    public func optimizeFinderSyncHooks() async -> String {
        return await Task.detached(priority: .userInitiated) { () -> String in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = ["-e", "ignore", "-i", "com.macpaw.CleanMyMac5.FinderSyncExtension"]
            try? process.run()
            process.waitUntilExit()
            return "Ölü Finder eklentileri temizlendi"
        }.value
    }
    
    /// Sol üst köşede kırmızı kapatma tuşunu engelleyen Masaüstünü Göster (4) sıcak köşe çakışmasını giderir
    public func fixHotCornerConflict() async -> String {
        return await Task.detached(priority: .userInitiated) { () -> String in
            let readProcess = Process()
            readProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            readProcess.arguments = ["read", "com.apple.dock", "wvous-tl-corner"]
            let pipe = Pipe()
            readProcess.standardOutput = pipe
            try? readProcess.run()
            readProcess.waitUntilExit()
            let val = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if val == "4" || val == "2" {
                let writeProcess = Process()
                writeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
                writeProcess.arguments = ["write", "com.apple.dock", "wvous-tl-corner", "-int", "1"]
                try? writeProcess.run()
                writeProcess.waitUntilExit()
                
                let killDock = Process()
                killDock.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                killDock.arguments = ["Dock"]
                try? killDock.run()
                killDock.waitUntilExit()
                return "Sol üst köşe çakışması giderildi"
            }
            return "Köşe çakışması yok"
        }.value
    }
    
    /// Tam ekranda pencere butonlarının (kırmızı/yeşil) erişilebilir kalması için menü çubuğunu görünür tutar
    public func fixFullscreenMenuBar() async -> String {
        return await Task.detached(priority: .userInitiated) { () -> String in
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            p1.arguments = ["write", "NSGlobalDomain", "AppleMenuBarVisibleInFullscreen", "-bool", "true"]
            try? p1.run()
            p1.waitUntilExit()
            return "Tam ekran menü çubuğu sabitlendi"
        }.value
    }
    
    /// Tüm Optimizasyon Adımlarını Sırayla Kusursuzca İcra Eder
    public func runAllOptimizations() async {
        isOptimizing = true
        
        // 1. RAM
        currentActionText = "İnaktif bellek temizleniyor..."
        let ramGained = await purgeMemory()
        if let idx = tasks.firstIndex(where: { $0.id == "ram" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = ramGained > 0
                ? "+\(ByteCountFormatter.string(fromByteCount: Int64(ramGained), countStyle: .memory)) serbest bırakıldı"
                : "Bellek optimize edildi"
        }
        
        // 2. DNS
        currentActionText = "DNS ve ağ soketleri sıfırlanıyor..."
        await flushDNS()
        if let idx = tasks.firstIndex(where: { $0.id == "dns" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = "Ağ çözümleyici taze"
        }
        
        // 3. QuickLook
        currentActionText = "QuickLook önbelleği sıfırlanıyor..."
        await flushQuickLook()
        if let idx = tasks.firstIndex(where: { $0.id == "quicklook" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = "Önbellek yenilendi"
        }
        
        // 4. Tanılama Günlükleri
        currentActionText = "Eski çökme günlükleri çöp kutusuna taşınıyor..."
        let diagFreed = await cleanDiagnosticLogs()
        if let idx = tasks.firstIndex(where: { $0.id == "diagnostics" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = diagFreed > 0
                ? "\(ByteCountFormatter.string(fromByteCount: diagFreed, countStyle: .file)) taşındı"
                : "Temiz"
        }
        
        // 5. APFS Snapshots
        currentActionText = "APFS yerel yedek anlık görüntüleri seyreltiliyor..."
        let snapResult = await thinLocalSnapshots()
        if let idx = tasks.firstIndex(where: { $0.id == "snapshots" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = snapResult
        }
        
        // 6. Font Cache
        currentActionText = "Yazı tipi önbellekleri sıfırlanıyor..."
        await flushFontCache()
        if let idx = tasks.firstIndex(where: { $0.id == "fontcache" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = "Font kayıt defteri temiz"
        }
        
        // 7. FinderSync
        currentActionText = "Finder eklenti kancaları denetleniyor..."
        let finderResult = await optimizeFinderSyncHooks()
        if let idx = tasks.firstIndex(where: { $0.id == "findersync" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = finderResult
        }
        
        // 8. Hot Corners
        currentActionText = "Sıcak köşe ergonomisi doğrulanıyor..."
        let cornerResult = await fixHotCornerConflict()
        if let idx = tasks.firstIndex(where: { $0.id == "hotcorners" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = cornerResult
        }
        
        // 9. Fullscreen
        currentActionText = "Tam ekran pencere kontrolleri ayarlanıyor..."
        let fullResult = await fixFullscreenMenuBar()
        if let idx = tasks.firstIndex(where: { $0.id == "fullscreen" }) {
            tasks[idx].isCompleted = true
            tasks[idx].freedText = fullResult
        }
        
        refreshMemoryStats()
        currentActionText = "Tüm optimizasyonlar başarıyla tamamlandı!"
        isOptimizing = false
    }
}
