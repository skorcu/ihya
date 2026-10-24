import Foundation
import Combine
import CryptoKit
#if canImport(Darwin)
import Darwin
#endif

public enum FileCategoryType: String, CaseIterable, Sendable {
    case all = "Tümü"
    case images = "Görseller"
    case videos = "Videolar"
    case documents = "Belgeler"
    case archives = "Arşivler & Kalıplar"
    case audio = "Ses & Müzik"
    case other = "Diğer"
    
    public static func from(path: String) -> FileCategoryType {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "webp", "heic", "gif", "svg", "tiff", "bmp", "raw", "cr2", "nef":
            return .images
        case "mp4", "mov", "mkv", "avi", "m4v", "wmv", "flv", "webm":
            return .videos
        case "pdf", "docx", "doc", "xlsx", "xls", "pptx", "txt", "md", "rtf", "pages", "numbers", "key":
            return .documents
        case "zip", "tar", "gz", "tgz", "dmg", "iso", "pkg", "rar", "7z":
            return .archives
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff":
            return .audio
        default:
            return .other
        }
    }
}

public struct ScanTargetItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let icon: String
    public let isExternalDisk: Bool
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        icon: String,
        isExternalDisk: Bool = false,
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.icon = icon
        self.isExternalDisk = isExternalDisk
        self.isSelected = isSelected
    }
}

public struct FolderDuplicateSummary: Identifiable, Sendable {
    public let id: String
    public let folderPath: String
    public let folderName: String
    public let count: Int
    public let totalSize: Int64
    
    public init(folderPath: String, count: Int, totalSize: Int64) {
        self.id = folderPath
        self.folderPath = folderPath
        self.folderName = (folderPath as NSString).lastPathComponent
        self.count = count
        self.totalSize = totalSize
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

@MainActor
public final class DuplicateFinderEngine: ObservableObject {
    public static let shared = DuplicateFinderEngine()
    
    // MARK: - Anlamlı Dosya Uzantıları ve Gürültü Filtresi
    nonisolated public static let commonMeaningfulExtensions: Set<String> = [
        // Video
        "mp4", "mov", "m4v", "mkv", "avi", "webm", "flv", "wmv",
        // Görseller
        "jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tiff", "tif", "svg", "raw", "cr2", "nef", "psd", "ai",
        // Belgeler
        "pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt", "pages", "numbers", "key", "txt", "rtf", "csv", "epub", "md",
        // Arşivler & İmajlar
        "zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg", "bz2", "xz",
        // Ses & Müzik
        "mp3", "wav", "m4a", "aac", "flac", "ogg", "aiff"
    ]
    
    nonisolated public static let noiseDirectories: Set<String> = [
        ".git", "node_modules", "deriveddata", ".build", ".gradle", ".cargo", "pods", ".venv", "__pycache__", "venv"
    ]
    
    nonisolated public static let noiseExtensions: Set<String> = [
        "dill", "bin", "pyc", "o", "a", "dylib", "class", "lock", "tmp", "swp", "log"
    ]
    
    @Published public var onlyCommonUserFiles: Bool = true
    @Published public var isScanning: Bool = false
    @Published public var hasScanned: Bool = false
    @Published public var scanProgress: DuplicateScanProgress? = nil
    @Published public var duplicateGroups: [DuplicateGroup] = []
    @Published public var cachedFolderSummaries: [FolderDuplicateSummary] = []
    @Published public var scanTargets: [ScanTargetItem] = []
    @Published public var selectedFilter: FileCategoryType = .all
    @Published public var isShowingFolderReport: Bool = false
    @Published public var selectedFolderFilter: String? = nil
    @Published public var protectedFolderPaths: Set<String> = []
    
    private var currentScanTask: Task<Void, Never>? = nil
    
    public init() {
        self.scanTargets = Self.defaultScanTargets()
    }
    
    /// Sistemde taranabilir disk ve ana klasörleri listeler
    public static func defaultScanTargets() -> [ScanTargetItem] {
        let home = NSHomeDirectory()
        var targets: [ScanTargetItem] = [
            ScanTargetItem(name: "İndirilenler", path: (home as NSString).appendingPathComponent("Downloads"), icon: "arrow.down.circle.fill", isSelected: true),
            ScanTargetItem(name: "Masaüstü", path: (home as NSString).appendingPathComponent("Desktop"), icon: "menubar.dock.rectangle", isSelected: true),
            ScanTargetItem(name: "Belgeler", path: (home as NSString).appendingPathComponent("Documents"), icon: "folder.fill", isSelected: true),
            ScanTargetItem(name: "Resimler", path: (home as NSString).appendingPathComponent("Pictures"), icon: "photo.on.rectangle.angled", isSelected: false),
            ScanTargetItem(name: "Filmler / Videolar", path: (home as NSString).appendingPathComponent("Movies"), icon: "film.fill", isSelected: false),
            ScanTargetItem(name: "Tüm Ev Dizini (~)", path: home, icon: "house.fill", isSelected: false)
        ]
        
        // Harici diskleri (/Volumes/*) dinamik ve akıllı tespit et
        let fm = FileManager.default
        let excludedVolumeKeywords: [String] = [
            "recovery", "preboot", "vm", "update", "time machine",
            "timemachine", "localsnapshots", "backup", ".timemachine"
        ]
        
        if let volContents = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for volName in volContents {
                // Gizli veya ana sistem diskini atla
                if volName.hasPrefix(".") || volName == "Macintosh HD" { continue }
                
                // Sistem, Recovery ve Time Machine yedek disklerini filtrele
                let lowerName = volName.lowercased()
                if excludedVolumeKeywords.contains(where: { lowerName.contains($0) }) {
                    continue
                }
                
                let volPath = "/Volumes/\(volName)"
                
                // Salt okunur diskleri atla (Time Machine vs.)
                let volURL = URL(fileURLWithPath: volPath)
                if let vals = try? volURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]), vals.volumeIsReadOnly == true {
                    continue
                }
                
                targets.append(ScanTargetItem(
                    name: "💽 \(volName)",
                    path: volPath,
                    icon: "externaldrive.fill",
                    isExternalDisk: true,
                    isSelected: false
                ))
            }
        }
        
        return targets
    }
    
    public func getAvailableScanTargets() -> [ScanTargetItem] {
        return scanTargets
    }
    
    /// Arka planda kesintisiz tarama başlatır (Kullanıcı diğer menülere geçse de devam eder)
    public func startBackgroundScan(targets: [String], onCompletion: (@Sendable () -> Void)? = nil) {
        guard !isScanning else { return }
        currentScanTask?.cancel()
        
        isScanning = true
        hasScanned = false
        scanProgress = DuplicateScanProgress(
            step: .sizeGrouping,
            currentPath: "Tarama başlatılıyor...",
            processedFiles: 0,
            totalCandidates: 0,
            foundDuplicateGroups: 0,
            progressFraction: 0.02
        )
        
        currentScanTask = Task { [weak self] in
            guard let self = self else { return }
            let groups = await self.scanDuplicates(in: targets) { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isScanning else { return }
                    self.scanProgress = progress
                }
            }
            
            if !Task.isCancelled {
                self.duplicateGroups = groups
                self.cachedFolderSummaries = self.getFolderSummaries(from: groups)
                self.hasScanned = true
                self.isScanning = false
                onCompletion?()
            }
        }
    }
    
    /// Devam eden taramayı anında durdurur
    public func cancelScan() {
        currentScanTask?.cancel()
        currentScanTask = nil
        isScanning = false
        scanProgress = nil
    }
    
    /// Tekli dizin için geriye dönük uyumlu tarama
    public func scanDuplicates(
        in directoryPath: String,
        minSize: Int64 = 4096,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)? = nil
    ) async -> [DuplicateGroup] {
        return await scanDuplicates(in: [directoryPath], minSize: minSize, onProgress: onProgress)
    }
    
    /// Çoklu disk ve klasörler arasında Eşzamanlı Çift Dosya Tarayıcı (POSIX + 4KB Prefix/Suffix + SHA-256)
    public func scanDuplicates(
        in directories: [String],
        minSize: Int64 = 4096,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)? = nil
    ) async -> [DuplicateGroup] {
        let validPaths = directories.filter { FileManager.default.fileExists(atPath: $0) }
        guard !validPaths.isEmpty else { return [] }
        if Task.isCancelled { return [] }
        
        onProgress?(DuplicateScanProgress(
            step: .sizeGrouping,
            currentPath: "Dizinler taranıyor...",
            processedFiles: 0,
            totalCandidates: 0,
            foundDuplicateGroups: 0,
            progressFraction: 0.05
        ))
        
        // 1. Aşama: Boyut Eşleme (Tüm seçilen dizinlerde)
        let filterCommonOnly = self.onlyCommonUserFiles
        let (candidatesBySize, totalScannedCount) = await Task.detached(priority: .userInitiated) {
            self.collectFilesBySize(inDirectories: validPaths, minSize: minSize, onlyCommonUserFiles: filterCommonOnly, onProgress: onProgress)
        }.value
        
        guard !candidatesBySize.isEmpty && !Task.isCancelled else {
            if !Task.isCancelled {
                onProgress?(DuplicateScanProgress(
                    step: .organizing,
                    currentPath: "Tarama tamamlandı (Çift dosya bulunamadı)",
                    totalScannedFiles: totalScannedCount,
                    processedCandidates: 0,
                    totalCandidates: 0,
                    foundDuplicateGroups: 0,
                    progressFraction: 1.0
                ))
            }
            return []
        }
        
        let totalCandidatesCount = candidatesBySize.values.reduce(0) { $0 + $1.count }
        
        // 2 & 3. Aşama: Prefix (4KB) ve Suffix (4KB) Hash Filtresi
        let candidatesByPartialHash = await self.filterByPartialHashes(
            candidatesBySize: candidatesBySize,
            totalScannedFiles: totalScannedCount,
            totalCandidateFiles: totalCandidatesCount,
            onProgress: onProgress
        )
        
        guard !candidatesByPartialHash.isEmpty && !Task.isCancelled else {
            if !Task.isCancelled {
                onProgress?(DuplicateScanProgress(
                    step: .organizing,
                    currentPath: "Tarama tamamlandı (Benzer boyutlu dosyalar farklı çıktı)",
                    totalScannedFiles: totalScannedCount,
                    processedCandidates: totalCandidatesCount,
                    totalCandidates: totalCandidatesCount,
                    foundDuplicateGroups: 0,
                    progressFraction: 1.0
                ))
            }
            return []
        }
        
        // 4. Aşama: Çok Çekirdekli Paralel Tam SHA-256 Doğrulama
        let fullHashGroups = await computeFullHashesConcurrently(
            candidates: candidatesByPartialHash,
            totalScannedFiles: totalScannedCount,
            onProgress: onProgress
        )
        if Task.isCancelled { return [] }
        
        onProgress?(DuplicateScanProgress(
            step: .organizing,
            currentPath: "İkiz dosya grupları tanzim ediliyor...",
            totalScannedFiles: totalScannedCount,
            processedCandidates: totalCandidatesCount,
            totalCandidates: totalCandidatesCount,
            foundDuplicateGroups: fullHashGroups.count,
            progressFraction: 0.98
        ))
        
        // 5. Aşama: Gruplama ve Orijinal Belirleme
        let results = organizeDuplicateGroups(fullHashGroups: fullHashGroups)
        
        onProgress?(DuplicateScanProgress(
            step: .organizing,
            currentPath: "İşlem tamamlandı: \(results.count) ikiz grup tespit edildi.",
            totalScannedFiles: totalScannedCount,
            processedCandidates: totalCandidatesCount,
            totalCandidates: totalCandidatesCount,
            foundDuplicateGroups: results.count,
            progressFraction: 1.0
        ))
        
        return results
    }
    
    // MARK: - 1. Aşama: Boyut Toplama (Çoklu Dizin)
    nonisolated private func collectFilesBySize(
        inDirectories dirs: [String],
        minSize: Int64,
        onlyCommonUserFiles: Bool,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) -> (candidates: [Int64: [String]], totalScannedCount: Int) {
        var sizeMap: [Int64: [String]] = [:]
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .ubiquitousItemDownloadingStatusKey
        ]
        let fm = FileManager.default
        var seenPaths = Set<String>()
        var scannedCount = 0
        var duplicateCandidatesCount = 0
        
        for dir in dirs {
            if Task.isCancelled { break }
            let rootURL = URL(fileURLWithPath: dir)
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else { continue }
            
            while let url = enumerator.nextObject() as? URL {
                if Task.isCancelled { break }
                let path = url.path
                if seenPaths.contains(path) { continue }
                seenPaths.insert(path)
                
                scannedCount += 1
                if scannedCount % 100 == 0 {
                    onProgress?(DuplicateScanProgress(
                        step: .sizeGrouping,
                        currentPath: path,
                        totalScannedFiles: scannedCount,
                        processedCandidates: duplicateCandidatesCount,
                        totalCandidates: duplicateCandidatesCount,
                        foundDuplicateGroups: 0,
                        progressFraction: min(0.30, Double(scannedCount) / 10000.0 * 0.30)
                    ))
                }
                
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true,
                      values.ubiquitousItemDownloadingStatus != .notDownloaded,
                      let size = values.fileSize,
                      Int64(size) >= minSize else { continue }
                
                // Anlamlı Kullanıcı Dosyası & Gürültü Süzgeci
                let lowerPath = path.lowercased()
                let ext = (path as NSString).pathExtension.lowercased()
                
                // Geliştirici ve derleyici önbellek klasörlerini atla
                let hasNoiseDir = Self.noiseDirectories.contains(where: { lowerPath.contains("/\($0)/") || lowerPath.hasSuffix("/\($0)") })
                if hasNoiseDir { continue }
                if Self.noiseExtensions.contains(ext) { continue }
                
                // Eğer sadece kullanıcı dosyaları seçiliyse (Varsayılan: Medya, Belgeler, Arşivler)
                if onlyCommonUserFiles && !Self.commonMeaningfulExtensions.contains(ext) {
                    continue
                }
                
                let fileSize = Int64(size)
                if let count = sizeMap[fileSize]?.count {
                    if count == 1 {
                        duplicateCandidatesCount += 2
                    } else {
                        duplicateCandidatesCount += 1
                    }
                    sizeMap[fileSize]?.append(path)
                } else {
                    sizeMap[fileSize] = [path]
                }
            }
        }
        
        let filtered = sizeMap.filter { $0.value.count > 1 }
        let totalCandidates = filtered.values.reduce(0) { $0 + $1.count }
        onProgress?(DuplicateScanProgress(
            step: .sizeGrouping,
            currentPath: "Boyut analizi tamamlandı (\(totalCandidates) aday dosya)",
            totalScannedFiles: scannedCount,
            processedCandidates: totalCandidates,
            totalCandidates: totalCandidates,
            foundDuplicateGroups: 0,
            progressFraction: 0.30
        ))
        return (filtered, scannedCount)
    }
    
    // MARK: - 2 & 3. Aşama: 4KB Prefix + 4KB Suffix Hash Filtresi (Çok Çekirdekli & Önbellek Destekli)
    nonisolated private func filterByPartialHashes(
        candidatesBySize: [Int64: [String]],
        totalScannedFiles: Int,
        totalCandidateFiles: Int,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) async -> [[String]] {
        let cacheSnapshot = await DuplicateHashCache.shared.getRecordsSnapshot()
        
        var candidateItems: [(path: String, size: Int64)] = []
        for (fileSize, paths) in candidatesBySize {
            for path in paths {
                candidateItems.append((path: path, size: fileSize))
            }
        }
        
        let total = candidateItems.count
        guard total > 0 else { return [] }
        
        var groupedByPartial: [String: [String]] = [:]
        var newCacheRecords: [FileHashRecord] = []
        
        var currentIndex = 0
        var processedCount = 0
        
        while currentIndex < total && !Task.isCancelled {
            let batchEnd = min(currentIndex + 128, total)
            let batch = Array(candidateItems[currentIndex..<batchEnd])
            currentIndex = batchEnd
            
            let batchResults = await withTaskGroup(of: (path: String, size: Int64, partialKey: String?, newRecord: FileHashRecord?).self) { group in
                for item in batch {
                    group.addTask {
                        let mtime = (try? FileManager.default.attributesOfItem(atPath: item.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                        
                        if let cached = cacheSnapshot[item.path],
                           abs(cached.mtime - mtime) < 0.001,
                           cached.size == item.size {
                            return (item.path, item.size, cached.partialKey, nil)
                        }
                        
                        if let computed = self.computePartialKey(path: item.path, fileSize: item.size) {
                            let rec = FileHashRecord(path: item.path, mtime: mtime, size: item.size, partialKey: computed, fullSHA256: nil)
                            return (item.path, item.size, computed, rec)
                        }
                        
                        return (item.path, item.size, nil, nil)
                    }
                }
                
                var results: [(path: String, size: Int64, partialKey: String?, newRecord: FileHashRecord?)] = []
                for await res in group {
                    results.append(res)
                }
                return results
            }
            
            for res in batchResults {
                processedCount += 1
                if let pk = res.partialKey {
                    let groupKey = "\(res.size)_\(pk)"
                    groupedByPartial[groupKey, default: []].append(res.path)
                }
                if let rec = res.newRecord {
                    newCacheRecords.append(rec)
                }
            }
            
            let fraction = 0.30 + (Double(processedCount) / Double(total)) * 0.35
            onProgress?(DuplicateScanProgress(
                step: .partialHash,
                currentPath: batch.last?.path ?? "Kısmi hash analizi...",
                totalScannedFiles: totalScannedFiles,
                processedCandidates: processedCount,
                totalCandidates: total,
                foundDuplicateGroups: 0,
                progressFraction: min(0.65, fraction)
            ))
            
            await Task.yield()
        }
        
        if !newCacheRecords.isEmpty {
            await DuplicateHashCache.shared.updateRecordsBulk(newCacheRecords)
            await DuplicateHashCache.shared.saveToDisk()
        }
        
        let candidateClusters = groupedByPartial.values.filter { $0.count > 1 }
        return Array(candidateClusters)
    }
    
    nonisolated private func computePartialKey(path: String, fileSize: Int64) -> String? {
        let fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        
        var st = stat()
        guard fstat(fd, &st) == 0 else { return nil }
        guard (st.st_mode & S_IFMT) == S_IFREG else { return nil }
        
        // iCloud Dataless veya çevrimdışı dosyaları atla (0x40000000 = UF_DATALESS)
        if (st.st_flags & 0x40000000) != 0 {
            return nil
        }
        
        let chunkSize = 4096
        var prefixBuffer = [UInt8](repeating: 0, count: chunkSize)
        let prefixRead = read(fd, &prefixBuffer, chunkSize)
        guard prefixRead > 0 else { return nil }
        
        var suffixBuffer = [UInt8](repeating: 0, count: chunkSize)
        var suffixRead = 0
        if fileSize > Int64(chunkSize * 2) {
            let offset = off_t(fileSize - Int64(chunkSize))
            if lseek(fd, offset, SEEK_SET) != -1 {
                let sRead = read(fd, &suffixBuffer, chunkSize)
                if sRead > 0 {
                    suffixRead = sRead
                }
            }
        }
        
        var hasher = SHA256()
        hasher.update(data: Data(prefixBuffer[0..<prefixRead]))
        if suffixRead > 0 {
            hasher.update(data: Data(suffixBuffer[0..<suffixRead]))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 4. Aşama: Çok Çekirdekli Paralel Tam SHA-256 (Kademeli & CPU Korumalı)
    nonisolated private func computeFullHashesConcurrently(
        candidates: [[String]],
        totalScannedFiles: Int,
        onProgress: (@Sendable (DuplicateScanProgress) -> Void)?
    ) async -> [String: (size: Int64, paths: [String])] {
        var allPaths: [String] = []
        for cluster in candidates {
            for path in cluster {
                allPaths.append(path)
            }
        }
        let totalFiles = allPaths.count
        guard totalFiles > 0 else { return [:] }
        
        // İşlemci yükünü sınırla: Max CPU / 2 worker (Diğer sekmelerin ve sistemin yavaşlamaması için)
        let maxWorkers = max(2, min(4, ProcessInfo.processInfo.activeProcessorCount / 2))
        
        return await withTaskGroup(of: (String, String, Int64)?.self) { group in
            var pathIterator = allPaths.makeIterator()
            var activeWorkers = 0
            
            while activeWorkers < maxWorkers, let path = pathIterator.next() {
                activeWorkers += 1
                group.addTask(priority: .utility) {
                    return await self.processSingleFileFullHash(path: path)
                }
            }
            
            var groups: [String: (size: Int64, paths: [String])] = [:]
            var processed = 0
            
            for await item in group {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                processed += 1
                
                if let nextPath = pathIterator.next(), !Task.isCancelled {
                    group.addTask(priority: .utility) {
                        return await self.processSingleFileFullHash(path: nextPath)
                    }
                }
                
                guard let (hash, path, size) = item else { continue }
                
                if processed % 5 == 0 || processed == totalFiles {
                    let fraction = 0.65 + (Double(processed) / Double(totalFiles)) * 0.30
                    let duplicateGroupCount = groups.values.filter { $0.paths.count > 1 }.count
                    onProgress?(DuplicateScanProgress(
                        step: .fullSHA256,
                        currentPath: path,
                        totalScannedFiles: totalScannedFiles,
                        processedCandidates: processed,
                        totalCandidates: totalFiles,
                        foundDuplicateGroups: duplicateGroupCount,
                        progressFraction: min(0.95, fraction)
                    ))
                }
                
                if groups[hash] == nil {
                    groups[hash] = (size: size, paths: [path])
                } else {
                    groups[hash]?.paths.append(path)
                }
                
                // Düzenli aralıklarla CPU serbest bırak (UI ve diğer sekmeler asla kasmasın)
                if processed % 15 == 0 {
                    await Task.yield()
                }
            }
            
            // Tarama tamamlandığında önbelleği diske yaz
            Task {
                await DuplicateHashCache.shared.saveToDisk()
            }
            
            return groups.filter { $0.value.paths.count > 1 }
        }
    }
    
    nonisolated private func processSingleFileFullHash(path: String) async -> (String, String, Int64)? {
        guard !Task.isCancelled else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attrs?[.size] as? Int64) ?? 0
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        
        // 1. Önbellek kontrolü: Dosya boyutu ve değiştirilme tarihi aynıysa diskten okumayı atla!
        if let cached = await DuplicateHashCache.shared.getRecord(path: path, currentMTime: mtime, currentSize: size),
           let fullHash = cached.fullSHA256 {
            return (fullHash, path, size)
        }
        
        // 2. Diski oku
        guard let hash = computeFullSHA256(path: path) else { return nil }
        
        // 3. Önbelleğe kaydet
        let partial = computePartialKey(path: path, fileSize: size) ?? ""
        await DuplicateHashCache.shared.setFullSHA256(path: path, mtime: mtime, size: size, partialKey: partial, fullSHA256: hash)
        
        return (hash, path, size)
    }
    
    nonisolated private func computeFullSHA256(path: String) -> String? {
        let fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        
        var st = stat()
        guard fstat(fd, &st) == 0 else { return nil }
        guard (st.st_mode & S_IFMT) == S_IFREG else { return nil }
        if (st.st_flags & 0x40000000) != 0 { return nil }
        
        var hasher = SHA256()
        let bufferSize = 262144 // 256 KB yüksek performanslı tampon
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        while true {
            if Task.isCancelled { return nil }
            let bytesRead = read(fd, &buffer, bufferSize)
            if bytesRead <= 0 { break }
            hasher.update(data: Data(buffer[0..<bytesRead]))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 5. Aşama: Gruplama ve Akıllı Orijinal Seçimi
    nonisolated private func organizeDuplicateGroups(fullHashGroups: [String: (size: Int64, paths: [String])]) -> [DuplicateGroup] {
        var result: [DuplicateGroup] = []
        
        for (hash, tuple) in fullHashGroups {
            let sortedPaths = tuple.paths.sorted { (p1, p2) -> Bool in
                let d1 = (try? FileManager.default.attributesOfItem(atPath: p1)[.creationDate] as? Date) ?? Date.distantPast
                let d2 = (try? FileManager.default.attributesOfItem(atPath: p2)[.creationDate] as? Date) ?? Date.distantPast
                return d1 < d2
            }
            
            var dupFiles: [DuplicateFile] = []
            for (index, p) in sortedPaths.enumerated() {
                let modDate = (try? FileManager.default.attributesOfItem(atPath: p)[.modificationDate] as? Date) ?? Date()
                let isOriginal = (index == 0)
                dupFiles.append(DuplicateFile(
                    path: p,
                    name: (p as NSString).lastPathComponent,
                    modifiedDate: modDate,
                    isOriginal: isOriginal,
                    isSelectedForDeletion: !isOriginal
                ))
            }
            
            result.append(DuplicateGroup(
                fileSize: tuple.size,
                sha256: hash,
                files: dupFiles
            ))
        }
        
        return result.sorted { $0.reclaimableSize > $1.reclaimableSize }
    }
    
    // MARK: - Akıllı Karar Kuralları
    nonisolated public func applyFolderRetentionRule(groups: [DuplicateGroup], keepFolderPath: String) -> [DuplicateGroup] {
        return groups.map { group in
            var updatedFiles = group.files
            let hasInKeepFolder = updatedFiles.contains { $0.path.hasPrefix(keepFolderPath) }
            
            if hasInKeepFolder {
                var keptOne = false
                for i in 0..<updatedFiles.count {
                    if updatedFiles[i].path.hasPrefix(keepFolderPath) && !keptOne {
                        updatedFiles[i].isOriginal = true
                        updatedFiles[i].isSelectedForDeletion = false
                        keptOne = true
                    } else {
                        updatedFiles[i].isOriginal = false
                        updatedFiles[i].isSelectedForDeletion = true
                    }
                }
            }
            return DuplicateGroup(id: group.id, fileSize: group.fileSize, sha256: group.sha256, files: updatedFiles)
        }
    }
    
    nonisolated public func applyDateRetentionRule(groups: [DuplicateGroup], keepOldest: Bool) -> [DuplicateGroup] {
        return groups.map { group in
            let sorted = group.files.sorted { f1, f2 in
                keepOldest ? f1.modifiedDate < f2.modifiedDate : f1.modifiedDate > f2.modifiedDate
            }
            var updated = sorted
            for i in 0..<updated.count {
                if i == 0 {
                    updated[i].isOriginal = true
                    updated[i].isSelectedForDeletion = false
                } else {
                    updated[i].isOriginal = false
                    updated[i].isSelectedForDeletion = true
                }
            }
            return DuplicateGroup(id: group.id, fileSize: group.fileSize, sha256: group.sha256, files: updated)
        }
    }
    
    nonisolated public func getFolderSummaries(from groups: [DuplicateGroup]) -> [FolderDuplicateSummary] {
        var folderStats: [String: (count: Int, size: Int64)] = [:]
        
        for g in groups {
            for f in g.files {
                let dir = (f.path as NSString).deletingLastPathComponent
                folderStats[dir, default: (0, 0)].count += 1
                folderStats[dir, default: (0, 0)].size += g.fileSize
            }
        }
        
        return folderStats.map { FolderDuplicateSummary(folderPath: $0.key, count: $0.value.count, totalSize: $0.value.size) }
            .sorted { $0.totalSize > $1.totalSize }
    }
}

