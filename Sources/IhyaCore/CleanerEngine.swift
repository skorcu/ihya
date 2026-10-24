import Foundation
import Combine

public enum ScanningPhase: String, Sendable {
    case idle
    case systemJunk = "system_junk"
    case browserCaches = "browser_caches"
    case developerVault = "developer_vault"
    case ghostDaemons = "ghost_daemons"
    case duplicates = "duplicates"
    case appLipo = "app_lipo"
    case completed
}

public final class CleanerEngine: ObservableObject, @unchecked Sendable {
    public static let shared = CleanerEngine()
    
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isCleaning: Bool = false
    @Published public private(set) var hasCleaned: Bool = false
    @Published public private(set) var currentTaskName: String = ""
    @Published public private(set) var currentScanningPath: String = ""
    @Published public private(set) var currentPhase: ScanningPhase = .idle
    @Published public private(set) var totalReclaimableBytes: Int64 = 0
    @Published public var categories: [CategorySummary] = []
    @Published public private(set) var duplicates: [DuplicateGroup] = []
    @Published public private(set) var ghostDaemons: [GhostDaemonItem] = []
    @Published public private(set) var lipoCandidates: [LipoItem] = []
    @Published public private(set) var mediaInventory: MediaInventoryStats = MediaInventoryStats()
    @Published public var availableUpdates: [AppUpdateItem] = []
    @Published public var totalInstalledAppsCount: Int = 0
    
    public var formattedTotalReclaimable: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
    }
    
    private init() {
        resetCategories()
    }
    
    public func resetCategories() {
        let coreTypes: [CleanCategoryType] = [.systemJunk, .browserCaches, .appResidues, .developerVault, .trashBins]
        self.categories = coreTypes.map { CategorySummary(category: $0) }
    }
    
    public func resetCleanedState() {
        self.hasCleaned = false
    }
    
    public func runFullScan() async {
        await MainActor.run {
            self.isScanning = true
            self.hasCleaned = false
            self.currentTaskName = "Sistem taranıyor..."
            self.currentScanningPath = "Taranıyor..."
            self.currentPhase = .systemJunk
        }
        
        // 1. Faz: Sistem Çöpleri, Derin Atıklar, Telefon Yedekleri ve Disk Kalıpları
        await updateTask("Sistem önbellekleri ve günlükler taranıyor...", phase: .systemJunk, path: "~/Library/Caches")
        var sysItems = await SystemRules.shared.scan()
        
        await updateTask("Telefon yedekleri, güncelleme atıkları ve kurulum dosyaları inceleniyor...", phase: .systemJunk, path: "~/Library/Application Support/MobileSync")
        let deepJunk = await DeepSystemJunkScanner.shared.scanDeepJunk()
        sysItems.append(contentsOf: deepJunk)
        
        await updateTask("Unutulmuş disk kalıpları taranıyor...", phase: .systemJunk, path: "~/Downloads/*.dmg")
        let diskImages = await UnusedDiskImagesScanner.shared.scanUnusedImages()
        sysItems.append(contentsOf: diskImages)
        
        // 2. Faz: Tarayıcı & Web Önbellekleri
        await updateTask("Safari, Chrome, Firefox ve web depoları taranıyor...", phase: .browserCaches, path: "~/Library/Containers/com.apple.Safari")
        let browserItems = await BrowserCacheEngine.shared.scanBrowserCaches()
        
        // 3. Faz: Geliştirici Kasası
        await updateTask("Xcode, Docker ve paket önbellekleri taranıyor...", phase: .developerVault, path: "~/Library/Developer/Xcode/DerivedData")
        let devItems = await DeveloperRules.shared.scan()
        
        // 4. Faz: Hayalet Servisler
        await updateTask("Hayalet servisler ve ölü ajanlar inceleniyor...", phase: .ghostDaemons, path: "~/Library/LaunchAgents")
        let ghosts = await GhostDaemonEngine.shared.scanGhostDaemons()
        
        // 5. Faz: Çift Dosyalar (İndirilenler & Masaüstü)
        await updateTask("Çift dosyalar ve ikiz kopyalar taranıyor...", phase: .duplicates, path: "~/Downloads")
        let home = NSHomeDirectory()
        let downloads = (home as NSString).appendingPathComponent("Downloads")
        let desktop = (home as NSString).appendingPathComponent("Desktop")
        let dupGroups = await DuplicateFinderEngine.shared.scanDuplicates(in: [downloads, desktop])
        
        // 6. Faz: Uygulama İnceltici (Lipo) & Yetim Artıklar
        await updateTask("Evrensel ikililer ve mimari fazlalıkları taranıyor...", phase: .appLipo, path: "/Applications")
        let lipoItems = await AppLipoEngine.shared.scanUniversalApps()
        let orphanItems = await AppResidueEngine.shared.scanOrphanResidues()
        
        // 7. Faz: Sistem Medya ve Dosya Dağılım Envanteri
        let inventory = await SystemMediaInventory.shared.scanInventory(duplicateGroups: dupGroups)
        
        // 8. Faz: Uygulamalar & Güncellemeler (Sparkle & Homebrew)
        await updateTask("Yüklü uygulamalar ve güncellemeler denetleniyor...", phase: .appLipo, path: "/Applications")
        let (updates, totalApps) = await AppUpdaterEngine.shared.scanAvailableUpdates()
        
        await MainActor.run {
            var updatedCats: [CategorySummary] = []
            
            // Sistem Çöpleri
            let sysSize = sysItems.reduce(0) { $0 + $1.size }
            updatedCats.append(CategorySummary(category: .systemJunk, totalSize: sysSize, items: sysItems))
            
            // Tarayıcı & Web Kasası
            let browserSize = browserItems.reduce(0) { $0 + $1.size }
            updatedCats.append(CategorySummary(category: .browserCaches, totalSize: browserSize, items: browserItems))
            
            // Yetim Artıklar
            let orphanSize = orphanItems.reduce(0) { $0 + $1.size }
            updatedCats.append(CategorySummary(category: .appResidues, totalSize: orphanSize, items: orphanItems))
            
            // Geliştirici Kasası
            let devSize = devItems.reduce(0) { $0 + $1.size }
            updatedCats.append(CategorySummary(category: .developerVault, totalSize: devSize, items: devItems))
            
            // Çöp Sepeti
            let trashPath = (home as NSString).appendingPathComponent(".Trash")
            let trashSize = FastScanner.shared.getPathSize(path: trashPath)
            var trashItems: [CleanItem] = []
            if trashSize > 0 {
                trashItems.append(CleanItem(
                    name: "Kullanıcı Çöp Sepeti",
                    path: trashPath,
                    size: trashSize,
                    category: .trashBins,
                    safety: .safe,
                    itemDescription: "Silinmek üzere bekleyen dosyalar"
                ))
            }
            updatedCats.append(CategorySummary(category: .trashBins, totalSize: trashSize, items: trashItems))
            
            self.categories = updatedCats
            self.ghostDaemons = ghosts
            self.duplicates = dupGroups
            self.lipoCandidates = lipoItems
            self.mediaInventory = inventory
            self.availableUpdates = updates
            self.totalInstalledAppsCount = totalApps
            
            let catTotal = updatedCats.reduce(0) { $0 + $1.totalSize }
            let lipoTotal = lipoItems.reduce(0) { $0 + $1.reclaimableSize }
            let dupTotal = dupGroups.reduce(0) { $0 + $1.reclaimableSize }
            self.totalReclaimableBytes = catTotal + lipoTotal + dupTotal
            
            self.isScanning = false
            self.currentPhase = .completed
            self.currentTaskName = "Tarama tamamlandı."
            self.currentScanningPath = ""
        }
    }
    
    public func performClean() async -> Int64 {
        await MainActor.run {
            self.isCleaning = true
            self.currentTaskName = "Arındırma işlemi başladı..."
        }
        
        var freedBytes: Int64 = 0
        
        for cat in categories where cat.isEnabled {
            for item in cat.items where item.isSelected {
                guard SafetyFilter.shared.isSafeToDelete(path: item.path) else { continue }
                
                await updateTask("Siliniyor: \(item.name)...", phase: .completed, path: item.path)
                do {
                    if cat.category == .trashBins {
                        if let contents = try? FileManager.default.contentsOfDirectory(atPath: item.path) {
                            for f in contents {
                                let sub = (item.path as NSString).appendingPathComponent(f)
                                try? FileManager.default.removeItem(atPath: sub)
                            }
                        }
                    } else {
                        try FileManager.default.removeItem(atPath: item.path)
                    }
                    freedBytes += item.size
                } catch {}
            }
        }
        
        SystemRules.shared.flushDNS()
        
        await MainActor.run {
            self.isCleaning = false
            self.hasCleaned = true
            self.currentTaskName = "Arındırma başarıyla tamamlandı!"
            self.currentScanningPath = ""
            self.totalReclaimableBytes = max(0, self.totalReclaimableBytes - freedBytes)
            self.resetCategories()
        }
        
        return freedBytes
    }
    
    public func performCleanCategory(_ categoryType: CleanCategoryType) async -> Int64 {
        await MainActor.run {
            self.isCleaning = true
            self.currentTaskName = "\(categoryType.displayName) arındırılıyor..."
        }
        
        var freedBytes: Int64 = 0
        
        guard let catIndex = categories.firstIndex(where: { $0.category == categoryType }) else {
            await MainActor.run { self.isCleaning = false }
            return 0
        }
        
        let cat = categories[catIndex]
        for item in cat.items where item.isSelected {
            guard SafetyFilter.shared.isSafeToDelete(path: item.path) else { continue }
            
            await updateTask("Siliniyor: \(item.name)...", phase: .completed, path: item.path)
            do {
                if cat.category == .trashBins {
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: item.path) {
                        for f in contents {
                            let sub = (item.path as NSString).appendingPathComponent(f)
                            try? FileManager.default.removeItem(atPath: sub)
                        }
                    }
                } else {
                    try FileManager.default.removeItem(atPath: item.path)
                }
                freedBytes += item.size
            } catch {}
        }
        
        await MainActor.run {
            self.isCleaning = false
            self.categories[catIndex].items.removeAll(where: { $0.isSelected })
            self.categories[catIndex].totalSize = self.categories[catIndex].items.reduce(0) { $0 + $1.size }
            self.totalReclaimableBytes = max(0, self.totalReclaimableBytes - freedBytes)
            self.currentTaskName = "\(categoryType.displayName) temizlendi."
            self.currentScanningPath = ""
            if self.totalReclaimableBytes == 0 {
                self.hasCleaned = true
            }
        }
        
        return freedBytes
    }
    
    public func removeAllGhostDaemons() {
        for ghost in ghostDaemons {
            try? FileManager.default.removeItem(atPath: ghost.plistPath)
        }
        self.ghostDaemons.removeAll()
    }
    
    public func removeGhostDaemon(id: String) {
        if let ghost = ghostDaemons.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(atPath: ghost.plistPath)
            ghostDaemons.removeAll(where: { $0.id == id })
        }
    }
    
    public func removeGhostDaemon(ghost: GhostDaemonItem) {
        try? FileManager.default.removeItem(atPath: ghost.plistPath)
        ghostDaemons.removeAll(where: { $0.id == ghost.id })
    }
    
    public func thinLipoItem(item: LipoItem) async -> (success: Bool, freedBytes: Int64) {
        let result = await AppLipoEngine.shared.thinAppBinary(item: item)
        if result.success {
            await MainActor.run {
                self.lipoCandidates.removeAll(where: { $0.id == item.id })
                self.totalReclaimableBytes = max(0, self.totalReclaimableBytes - result.freedBytes)
            }
        }
        return result
    }
    
    public func thinAllLipoItems() async -> Int64 {
        var totalFreed: Int64 = 0
        let items = lipoCandidates
        for item in items {
            let res = await thinLipoItem(item: item)
            if res.success {
                totalFreed += res.freedBytes
            }
        }
        return totalFreed
    }
    
    public func toggleItemSelection(categoryType: CleanCategoryType, itemId: String) {
        guard let catIdx = categories.firstIndex(where: { $0.category == categoryType }) else { return }
        if let itemIdx = categories[catIdx].items.firstIndex(where: { $0.id == itemId }) {
            categories[catIdx].items[itemIdx].isSelected.toggle()
            let catTotal = categories.reduce(0) { $0 + $1.totalSize }
            let lipoTotal = lipoCandidates.reduce(0) { $0 + $1.reclaimableSize }
            let dupTotal = duplicates.reduce(0) { $0 + $1.reclaimableSize }
            self.totalReclaimableBytes = catTotal + lipoTotal + dupTotal
        }
    }
    
    private func updateTask(_ name: String, phase: ScanningPhase, path: String = "") async {
        await MainActor.run {
            self.currentTaskName = name
            self.currentScanningPath = path
            self.currentPhase = phase
        }
    }
}
