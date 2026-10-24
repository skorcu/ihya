import Foundation
import AppKit

public enum LargeFileCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "Tüm Türler"
    case diskImage = "Disk Kalıpları (.dmg, .iso)"
    case archive = "Arşivler (.zip, .tar, .7z)"
    case media = "Videolar & Medya"
    case document = "Dev Belgeler & Veri"
    case other = "Diğer Dosyalar"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .diskImage: return "internaldrive"
        case .archive: return "archivebox.fill"
        case .media: return "film.fill"
        case .document: return "doc.text.fill"
        case .other: return "doc.fill"
        }
    }
}

public enum LargeFileSizeGroup: String, CaseIterable, Identifiable, Sendable {
    case all = "Tüm Boyutlar (100 MB+)"
    case huge5GB = "5 GB Üzeri"
    case large1GB = "1 GB - 5 GB"
    case medium500MB = "500 MB - 1 GB"
    case small100MB = "100 MB - 500 MB"
    
    public var id: String { rawValue }
}

public enum LargeFileTimeGroup: String, CaseIterable, Identifiable, Sendable {
    case all = "Tüm Zamanlar"
    case olderThanYear = "1 Yıldan Eski"
    case olderThanSixMonths = "6 Aydan Eski"
    case olderThanMonth = "1 Aydan Eski"
    case recent = "Son 1 Ay"
    
    public var id: String { rawValue }
}

public struct LargeOldFileItem: Identifiable, Hashable, Sendable {
    public let id: String // path
    public let path: String
    public let name: String
    public let size: Int64
    public let formattedSize: String
    public let lastAccessDate: Date
    public let lastModifiedDate: Date
    public let category: LargeFileCategory
    public let timeGroup: LargeFileTimeGroup
    public let sizeGroup: LargeFileSizeGroup
    public var isSelected: Bool = false
    
    public init(
        path: String,
        name: String,
        size: Int64,
        lastAccessDate: Date,
        lastModifiedDate: Date,
        category: LargeFileCategory,
        timeGroup: LargeFileTimeGroup,
        sizeGroup: LargeFileSizeGroup,
        isSelected: Bool = false
    ) {
        self.id = path
        self.path = path
        self.name = name
        self.size = size
        self.formattedSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        self.lastAccessDate = lastAccessDate
        self.lastModifiedDate = lastModifiedDate
        self.category = category
        self.timeGroup = timeGroup
        self.sizeGroup = sizeGroup
        self.isSelected = isSelected
    }
    
    public var relativeAccessTimeText: String {
        let now = Date()
        let interval = now.timeIntervalSince(lastAccessDate)
        let days = Int(interval / 86400)
        
        if days >= 365 {
            let years = days / 365
            return "\(years) yıl önce açıldı"
        } else if days >= 30 {
            let months = days / 30
            return "\(months) ay önce açıldı"
        } else if days > 0 {
            return "\(days) gün önce açıldı"
        } else {
            return "Bugün açıldı"
        }
    }
}

public struct ExternalStorageDisk: Identifiable, Hashable, Sendable {
    public let id: String // path
    public let name: String
    public let path: String
    public let freeBytes: Int64
    public let totalBytes: Int64
    
    public init(name: String, path: String, freeBytes: Int64, totalBytes: Int64) {
        self.id = path
        self.name = name
        self.path = path
        self.freeBytes = freeBytes
        self.totalBytes = totalBytes
    }
    
    public var formattedFreeSpace: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
    
    public var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}

@MainActor
public final class LargeOldFilesEngine: ObservableObject {
    public static let shared = LargeOldFilesEngine()
    
    @Published public var items: [LargeOldFileItem] = []
    @Published public var isScanning: Bool = false
    @Published public var hasScanned: Bool = false
    @Published public var currentScanningPath: String = ""
    @Published public var scannedFilesCount: Int = 0
    @Published public var scanProgress: Double = 0.0
    @Published public var availableExternalDisks: [ExternalStorageDisk] = []
    
    // Taşıma (Offload) Durumu
    @Published public var isOffloading: Bool = false
    @Published public var offloadProgressText: String = ""
    @Published public var offloadProgressFraction: Double = 0.0
    
    // Filtreler
    @Published public var selectedCategory: LargeFileCategory = .all
    @Published public var selectedSizeGroup: LargeFileSizeGroup = .all
    @Published public var selectedTimeGroup: LargeFileTimeGroup = .all
    @Published public var searchQuery: String = ""
    
    // İptal mekanizması
    private var isCancelled: Bool = false
    
    private init() {}
    
    // Filtrelenmiş Liste
    public var filteredItems: [LargeOldFileItem] {
        items.filter { item in
            // Kategori filtresi
            if selectedCategory != .all && item.category != selectedCategory {
                return false
            }
            // Boyut filtresi
            if selectedSizeGroup != .all && item.sizeGroup != selectedSizeGroup {
                return false
            }
            // Zaman filtresi
            if selectedTimeGroup != .all && item.timeGroup != selectedTimeGroup {
                return false
            }
            // Arama sorgusu
            if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let query = searchQuery.lowercased()
                return item.name.lowercased().contains(query) || item.path.lowercased().contains(query)
            }
            return true
        }
    }
    
    public var totalReclaimableBytes: Int64 {
        filteredItems.reduce(0) { $0 + $1.size }
    }
    
    public var selectedReclaimableBytes: Int64 {
        filteredItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    public var selectedCount: Int {
        filteredItems.filter { $0.isSelected }.count
    }
    
    // MARK: - Tarama Başlatma
    public func scan(minimumSize: Int64 = 100 * 1024 * 1024) async {
        guard !isScanning else { return }
        
        isScanning = true
        hasScanned = false
        isCancelled = false
        items = []
        scannedFilesCount = 0
        scanProgress = 0.0
        currentScanningPath = "Mac depolama haritası hazırlanıyor..."
        
        let targetDirectories: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures"),
            FileManager.default.homeDirectoryForCurrentUser
        ]
        
        let discoveredItems = await Task.detached(priority: .userInitiated) { () -> [LargeOldFileItem] in
            var results: [LargeOldFileItem] = []
            var visitedPaths = Set<String>()
            let fm = FileManager.default
            
            // Atlanacak gizli/sistem dizinleri
            let excludedFolderNames: Set<String> = [
                ".git", ".Trash", "Caches", "Containers", "Group Containers",
                "node_modules", ".build", "Pods", "DerivedData", "System",
                "Library", ".Spotlight-V100", ".fseventsd"
            ]
            
            let resourceKeys: Set<URLResourceKey> = [
                .fileSizeKey,
                .contentAccessDateKey,
                .contentModificationDateKey,
                .isRegularFileKey,
                .isPackageKey
            ]
            
            for (dirIndex, dirURL) in targetDirectories.enumerated() {
                guard fm.fileExists(atPath: dirURL.path) else { continue }
                
                let progressBase = Double(dirIndex) / Double(targetDirectories.count)
                
                let enumerator = fm.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsPackageDescendants, .skipsHiddenFiles]
                )
                
                var localCounter = 0
                
                while let fileURL = enumerator?.nextObject() as? URL {
                    let path = fileURL.path
                    
                    // Klasör adı kontrolü - atla
                    let lastComp = fileURL.lastPathComponent
                    if excludedFolderNames.contains(lastComp) {
                        enumerator?.skipDescendants()
                        continue
                    }
                    
                    // Zaten incelendi mi?
                    if visitedPaths.contains(path) {
                        continue
                    }
                    visitedPaths.insert(path)
                    
                    localCounter += 1
                    if localCounter % 150 == 0 {
                        let currentPath = path
                        let count = visitedPaths.count
                        let frac = progressBase + (Double(localCounter % 1000) / 1000.0) * (1.0 / Double(targetDirectories.count))
                        Task { @MainActor in
                            LargeOldFilesEngine.shared.scannedFilesCount = count
                            LargeOldFilesEngine.shared.currentScanningPath = currentPath
                            LargeOldFilesEngine.shared.scanProgress = min(0.95, frac)
                        }
                    }
                    
                    guard let vals = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
                    
                    // Sadece normal dosyalar (paket olmayan veya DMG/ISO gibi tekil dosyalar)
                    guard vals.isRegularFile == true else { continue }
                    
                    let size = Int64(vals.fileSize ?? 0)
                    guard size >= minimumSize else { continue }
                    
                    let accessDate = vals.contentAccessDate ?? vals.contentModificationDate ?? Date()
                    let modDate = vals.contentModificationDate ?? accessDate
                    
                    let category = LargeOldFilesEngine.classifyCategory(path: path)
                    let timeGroup = LargeOldFilesEngine.classifyTimeGroup(date: accessDate)
                    let sizeGroup = LargeOldFilesEngine.classifySizeGroup(size: size)
                    
                    let item = LargeOldFileItem(
                        path: path,
                        name: fileURL.lastPathComponent,
                        size: size,
                        lastAccessDate: accessDate,
                        lastModifiedDate: modDate,
                        category: category,
                        timeGroup: timeGroup,
                        sizeGroup: sizeGroup,
                        isSelected: false
                    )
                    
                    results.append(item)
                }
            }
            
            // En büyükten küçüğe sırala
            results.sort { $0.size > $1.size }
            return results
        }.value
        
        self.items = discoveredItems
        self.isScanning = false
        self.hasScanned = true
        self.scanProgress = 1.0
        self.currentScanningPath = "\(discoveredItems.count) adet dev dosya tespit edildi."
        
        // Bağlı harici diskleri tara
        self.refreshExternalDisks()
    }
    
    // MARK: - Harici Diskleri Tespit Etme
    public func refreshExternalDisks() {
        var disks: [ExternalStorageDisk] = []
        let fm = FileManager.default
        let excludedVolumeKeywords: [String] = [
            "recovery", "preboot", "vm", "update", "time machine",
            "timemachine", "localsnapshots", "backup", ".timemachine"
        ]
        
        guard let volContents = try? fm.contentsOfDirectory(atPath: "/Volumes") else {
            self.availableExternalDisks = []
            return
        }
        
        let resourceKeys: Set<URLResourceKey> = [
            .volumeIsReadOnlyKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey
        ]
        
        for volName in volContents {
            if volName.hasPrefix(".") || volName == "Macintosh HD" { continue }
            let lower = volName.lowercased()
            if excludedVolumeKeywords.contains(where: { lower.contains($0) }) { continue }
            
            let volPath = "/Volumes/\(volName)"
            let url = URL(fileURLWithPath: volPath)
            
            guard let vals = try? url.resourceValues(forKeys: resourceKeys) else { continue }
            if vals.volumeIsReadOnly == true { continue }
            
            let freeSpace = Int64(vals.volumeAvailableCapacity ?? 0)
            let totalSpace = Int64(vals.volumeTotalCapacity ?? 0)
            
            disks.append(ExternalStorageDisk(
                name: volName,
                path: volPath,
                freeBytes: freeSpace,
                totalBytes: totalSpace
            ))
        }
        
        self.availableExternalDisks = disks
    }
    
    // MARK: - Harici Diske Güvenli Arşivleme / Taşıma (Smart Offload)
    public func offloadSelectedFiles(to disk: ExternalStorageDisk) async -> (successCount: Int, movedBytes: Int64, errorText: String?) {
        guard !isOffloading else { return (0, 0, "İşlem zaten devam ediyor.") }
        
        isOffloading = true
        offloadProgressText = "Arşiv dizini hazırlanıyor..."
        offloadProgressFraction = 0.0
        
        let selectedList = items.filter { $0.isSelected }
        guard !selectedList.isEmpty else {
            isOffloading = false
            return (0, 0, "Taşınacak dosya seçilmedi.")
        }
        
        let totalBytesToMove = selectedList.reduce(0) { $0 + $1.size }
        if disk.freeBytes < totalBytesToMove {
            isOffloading = false
            return (0, 0, "'\(disk.name)' diskinde yeterli boş alan yok (Gereken: \(ByteCountFormatter.string(fromByteCount: totalBytesToMove, countStyle: .file)), Boş: \(disk.formattedFreeSpace))")
        }
        
        let fm = FileManager.default
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateFolder = dateFormatter.string(from: Date())
        let archiveBasePath = (disk.path as NSString)
            .appendingPathComponent("İhyâ Arşivi")
        let targetFolder = (archiveBasePath as NSString)
            .appendingPathComponent(dateFolder)
        
        do {
            try fm.createDirectory(atPath: targetFolder, withIntermediateDirectories: true)
        } catch {
            isOffloading = false
            return (0, 0, "Harici diskte arşiv klasörü oluşturulamadı: \(error.localizedDescription)")
        }
        
        var success = 0
        var moved: Int64 = 0
        var movedIds = Set<String>()
        
        for (index, item) in selectedList.enumerated() {
            let srcURL = URL(fileURLWithPath: item.path)
            let destPath = (targetFolder as NSString).appendingPathComponent(item.name)
            let destURL = URL(fileURLWithPath: destPath)
            
            offloadProgressText = "Taşınıyor: \(item.name) (\(item.formattedSize))..."
            offloadProgressFraction = Double(index) / Double(selectedList.count)
            
            // Eğer hedefte aynı isimde dosya varsa üzerine yazma, benzersiz ad ver
            var finalDestURL = destURL
            if fm.fileExists(atPath: destPath) {
                let ext = (item.name as NSString).pathExtension
                let base = (item.name as NSString).deletingPathExtension
                let uniqueName = "\(base)_\(Int(Date().timeIntervalSince1970)).\(ext)"
                finalDestURL = URL(fileURLWithPath: (targetFolder as NSString).appendingPathComponent(uniqueName))
            }
            
            do {
                // 1. Kopyala
                try fm.copyItem(at: srcURL, to: finalDestURL)
                
                // 2. Doğrula (Boyut eşleşiyor mu?)
                let destAttrs = try fm.attributesOfItem(atPath: finalDestURL.path)
                let destSize = destAttrs[.size] as? Int64 ?? 0
                
                if destSize == item.size {
                    // 3. Boyut birebir tutuyorsa, orijinali Mac SSD'den sil (veya Çöp Sepetine at)
                    try fm.removeItem(at: srcURL)
                    success += 1
                    moved += item.size
                    movedIds.insert(item.id)
                } else {
                    // Hatalı kopyalanmışsa hedefi sil, kaynağı koru!
                    try? fm.removeItem(at: finalDestURL)
                }
            } catch {
                print("Taşıma hatası: \(error.localizedDescription)")
            }
        }
        
        // Taşınanları listeden kaldır
        items.removeAll { movedIds.contains($0.id) }
        
        isOffloading = false
        offloadProgressFraction = 1.0
        offloadProgressText = "Tamamlandı!"
        refreshExternalDisks()
        
        return (success, moved, nil)
    }
    
    public func cancelScan() {
        isCancelled = true
        isScanning = false
    }
    
    // MARK: - Sınıflandırma Mantığı (nonisolated - arka plan tasklerinden çağrılabilir)
    nonisolated public static func classifyCategory(path: String) -> LargeFileCategory {
        let ext = (path as NSString).pathExtension.lowercased()
        
        switch ext {
        case "dmg", "iso", "img", "vdi", "vmdk", "qcow2", "sparseimage", "sparsebundle":
            return .diskImage
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "zst":
            return .archive
        case "mp4", "mov", "mkv", "avi", "m4v", "flv", "wmv", "webm", "wav", "aif", "aiff", "flac", "psd", "raw", "cr2", "nef":
            return .media
        case "pdf", "docx", "xlsx", "pptx", "sqlite", "db", "csv", "sql", "dump":
            return .document
        default:
            return .other
        }
    }
    
    nonisolated public static func classifyTimeGroup(date: Date) -> LargeFileTimeGroup {
        let days = Int(Date().timeIntervalSince(date) / 86400)
        if days >= 365 {
            return .olderThanYear
        } else if days >= 180 {
            return .olderThanSixMonths
        } else if days >= 30 {
            return .olderThanMonth
        } else {
            return .recent
        }
    }
    
    nonisolated public static func classifySizeGroup(size: Int64) -> LargeFileSizeGroup {
        let gigabyte: Int64 = 1024 * 1024 * 1024
        if size >= 5 * gigabyte {
            return .huge5GB
        } else if size >= gigabyte {
            return .large1GB
        } else if size >= 500 * 1024 * 1024 {
            return .medium500MB
        } else {
            return .small100MB
        }
    }
    
    // MARK: - Seçim Eylemleri
    public func toggleSelection(for id: String) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].isSelected.toggle()
        }
    }
    
    public func selectAllFiltered() {
        let filteredIds = Set(filteredItems.map { $0.id })
        for idx in items.indices {
            if filteredIds.contains(items[idx].id) {
                items[idx].isSelected = true
            }
        }
    }
    
    public func selectOlderThanYear() {
        for idx in items.indices {
            if items[idx].timeGroup == .olderThanYear {
                items[idx].isSelected = true
            }
        }
    }
    
    public func selectAbove5GB() {
        for idx in items.indices {
            if items[idx].sizeGroup == .huge5GB {
                items[idx].isSelected = true
            }
        }
    }
    
    public func deselectAll() {
        for idx in items.indices {
            items[idx].isSelected = false
        }
    }
    
    // MARK: - Çöp Sepetine Taşıma (Geri Alınabilir)
    public func trashSelected() async -> (successCount: Int, freedBytes: Int64) {
        let selectedList = items.filter { $0.isSelected }
        var success = 0
        var freed: Int64 = 0
        var deletedIds = Set<String>()
        
        for item in selectedList {
            let url = URL(fileURLWithPath: item.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                success += 1
                freed += item.size
                deletedIds.insert(item.id)
            } catch {
                // Alternatif olarak removeItem fallback veya sessiz atlama
                print("Trash hatası: \(error.localizedDescription)")
            }
        }
        
        // Başarıyla silinenleri yerel listeden kaldır
        items.removeAll { deletedIds.contains($0.id) }
        
        return (success, freed)
    }
    
    // MARK: - Askeri Seviye Kalıcı Dosya Öğütücü (Shredder)
    /// Dosyanın üzerine rastgele baytlar ve sıfırlar yazarak blokları geri getirilemez şekilde ezer ve unbind eder
    public func shredFile(at path: String) throws {
        let fileURL = URL(fileURLWithPath: path)
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: path) else { return }
        
        let attrs = try fm.attributesOfItem(atPath: path)
        guard let fileSize = attrs[.size] as? Int64, fileSize > 0 else {
            try fm.removeItem(at: fileURL)
            return
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            let chunkSize = min(Int(fileSize), 4 * 1024 * 1024) // 4 MB bloklar
            let zeroData = Data(count: chunkSize)
            var bytesWritten: Int64 = 0
            
            // 1. Tur: Sıfırlarla ez
            fileHandle.seek(toFileOffset: 0)
            while bytesWritten < fileSize {
                let remaining = Int(fileSize - bytesWritten)
                let toWrite = min(chunkSize, remaining)
                fileHandle.write(zeroData.subdata(in: 0..<toWrite))
                bytesWritten += Int64(toWrite)
            }
            
            // 2. Tur: Rastgele baytlarla ez
            fileHandle.seek(toFileOffset: 0)
            bytesWritten = 0
            while bytesWritten < fileSize {
                let remaining = Int(fileSize - bytesWritten)
                let toWrite = min(chunkSize, remaining)
                var randomBytes = [UInt8](repeating: 0, count: toWrite)
                _ = SecRandomCopyBytes(kSecRandomDefault, toWrite, &randomBytes)
                fileHandle.write(Data(randomBytes))
                bytesWritten += Int64(toWrite)
            }
            
            try? fileHandle.synchronize()
            try? fileHandle.close()
        }
        
        // Bloklar ezildikten sonra diskten kaldır
        try fm.removeItem(at: fileURL)
        
        // Listeden sil
        items.removeAll { $0.path == path }
    }
}
