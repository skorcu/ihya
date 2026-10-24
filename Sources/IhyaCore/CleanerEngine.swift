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
    @Published public private(set) var lastFreedBytes: Int64 = 0
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
    
    public var formattedLastFreed: String {
        ByteCountFormatter.string(fromByteCount: lastFreedBytes, countStyle: .file)
    }
    
    private init() {
        resetCategories()
    }
    
    public func recalculateTotalReclaimable() {
        self.totalReclaimableBytes = self.categories.filter { $0.isEnabled }.reduce(0) { catSum, cat in
            catSum + cat.selectedSize
        }
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
        
        // 5. Faz: Uygulama İnceltici (Lipo) & Yetim Artıklar
        await updateTask("Evrensel ikililer ve mimari fazlalıkları taranıyor...", phase: .appLipo, path: "/Applications")
        let lipoItems = await AppLipoEngine.shared.scanUniversalApps()
        let orphanItems = await AppResidueEngine.shared.scanOrphanResidues()
        
        // 6. Faz: Sistem Medya ve Dosya Dağılım Envanteri
        let inventory = await SystemMediaInventory.shared.scanInventory()
        
        // 7. Faz: Uygulamalar & Güncellemeler (Sparkle & Homebrew)
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
            let home = NSHomeDirectory()
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
            self.duplicates = []
            self.lipoCandidates = lipoItems
            self.mediaInventory = inventory
            self.availableUpdates = updates
            self.totalInstalledAppsCount = totalApps
            
            // Sadece arındırılabilir ve seçili olan sistem çöpleri dahil edilir (Şahsî dosyalar & seçilmemiş yedekler sayılmaz)
            self.recalculateTotalReclaimable()
            
            self.isScanning = false
            self.currentPhase = .completed
            self.currentTaskName = "Tarama tamamlandı."
            self.currentScanningPath = ""
        }
    }
    
    public func performClean() async -> Int64 {
        await MainActor.run {
            self.isCleaning = true
            self.hasCleaned = false
            self.currentTaskName = "Arındırma işlemi başladı..."
        }
        
        var freedBytes: Int64 = 0
        
        for catIdx in 0..<categories.count {
            guard categories[catIdx].isEnabled else { continue }
            var remainingItems: [CleanItem] = []
            
            for item in categories[catIdx].items {
                if item.isSelected {
                    guard SafetyFilter.shared.isSafeToDelete(path: item.path) else {
                        remainingItems.append(item)
                        continue
                    }
                    
                    await updateTask("Arındırılıyor: \(item.name)...", phase: .completed, path: item.path)
                    
                    let (success, freed) = safeRemoveItem(at: item.path, category: categories[catIdx].category)
                    if success || freed > 0 {
                        freedBytes += (freed > 0 ? freed : item.size)
                    } else {
                        var uncleaned = item
                        uncleaned.isSelected = false
                        remainingItems.append(uncleaned)
                    }
                } else {
                    // Seçilmemiş öğeler (örneğin telefon yedeği veya korunmuş dosyalar) ASLA SİLİNMEZ!
                    remainingItems.append(item)
                }
            }
            
            let updatedItems = remainingItems
            await MainActor.run {
                self.categories[catIdx].items = updatedItems
                self.categories[catIdx].totalSize = updatedItems.reduce(0) { $0 + $1.size }
            }
        }
        
        SystemRules.shared.flushDNS()
        
        await MainActor.run {
            self.isCleaning = false
            self.hasCleaned = true
            self.lastFreedBytes = freedBytes
            self.currentTaskName = "Arındırma başarıyla tamamlandı!"
            self.currentScanningPath = ""
            self.recalculateTotalReclaimable()
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
        
        var remainingItems: [CleanItem] = []
        for item in categories[catIndex].items {
            if item.isSelected {
                guard SafetyFilter.shared.isSafeToDelete(path: item.path) else {
                    remainingItems.append(item)
                    continue
                }
                
                await updateTask("Arındırılıyor: \(item.name)...", phase: .completed, path: item.path)
                let (success, freed) = safeRemoveItem(at: item.path, category: categoryType)
                if success || freed > 0 {
                    freedBytes += (freed > 0 ? freed : item.size)
                } else {
                    var uncleaned = item
                    uncleaned.isSelected = false
                    remainingItems.append(uncleaned)
                }
            } else {
                remainingItems.append(item)
            }
        }
        
        let updatedItems = remainingItems
        await MainActor.run {
            self.isCleaning = false
            self.categories[catIndex].items = updatedItems
            self.categories[catIndex].totalSize = updatedItems.reduce(0) { $0 + $1.size }
            self.recalculateTotalReclaimable()
            self.currentTaskName = "\(categoryType.displayName) temizlendi."
            self.currentScanningPath = ""
            if self.totalReclaimableBytes == 0 {
                self.hasCleaned = true
            }
        }
        
        return freedBytes
    }
    
    private func safeRemoveItem(at path: String, category: CleanCategoryType) -> (success: Bool, freedBytes: Int64) {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var isDir: ObjCBool = false
        
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return (true, 0)
        }
        
        // Ana sistem/kullanıcı kök klasörlerinin kendisi silinmez, İÇERİĞİ silinir
        let rootContainerFolders = [
            (home as NSString).appendingPathComponent("Library/Logs"),
            (home as NSString).appendingPathComponent("Library/Caches"),
            (home as NSString).appendingPathComponent(".Trash")
        ]
        
        if rootContainerFolders.contains(path) || category == .trashBins {
            var freed: Int64 = 0
            if let contents = try? fm.contentsOfDirectory(atPath: path) {
                for file in contents {
                    let subPath = (path as NSString).appendingPathComponent(file)
                    let subSize = FastScanner.shared.getPathSize(path: subPath)
                    do {
                        try fm.removeItem(atPath: subPath)
                        freed += subSize
                    } catch {
                        freed += removeDirectoryContents(at: subPath)
                    }
                }
            }
            return (true, freed)
        }
        
        let size = FastScanner.shared.getPathSize(path: path)
        do {
            try fm.removeItem(atPath: path)
            return (true, size)
        } catch {
            if isDir.boolValue {
                let partialFreed = removeDirectoryContents(at: path)
                try? fm.removeItem(atPath: path)
                return (partialFreed > 0, partialFreed)
            }
            return (false, 0)
        }
    }
    
    private func removeDirectoryContents(at dirPath: String) -> Int64 {
        let fm = FileManager.default
        var freed: Int64 = 0
        guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { return 0 }
        
        for file in files {
            let full = (dirPath as NSString).appendingPathComponent(file)
            var isSubDir: ObjCBool = false
            if fm.fileExists(atPath: full, isDirectory: &isSubDir) {
                let s = FastScanner.shared.getPathSize(path: full)
                if isSubDir.boolValue {
                    freed += removeDirectoryContents(at: full)
                    try? fm.removeItem(atPath: full)
                } else {
                    do {
                        try fm.removeItem(atPath: full)
                        freed += s
                    } catch {}
                }
            }
        }
        return freed
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
            self.recalculateTotalReclaimable()
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
