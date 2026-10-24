import Foundation
import CryptoKit

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

public final class DuplicateFinderEngine: Sendable {
    public static let shared = DuplicateFinderEngine()
    
    public init() {}
    
    /// Sistemde taranabilir disk ve ana klasörleri listeler
    public func getAvailableScanTargets() -> [ScanTargetItem] {
        let home = NSHomeDirectory()
        var targets: [ScanTargetItem] = [
            ScanTargetItem(name: "İndirilenler", path: (home as NSString).appendingPathComponent("Downloads"), icon: "arrow.down.circle.fill", isSelected: true),
            ScanTargetItem(name: "Masaüstü", path: (home as NSString).appendingPathComponent("Desktop"), icon: "menubar.dock.rectangle", isSelected: true),
            ScanTargetItem(name: "Belgeler", path: (home as NSString).appendingPathComponent("Documents"), icon: "folder.fill", isSelected: true),
            ScanTargetItem(name: "Resimler", path: (home as NSString).appendingPathComponent("Pictures"), icon: "photo.on.rectangle.angled", isSelected: false),
            ScanTargetItem(name: "Filmler / Videolar", path: (home as NSString).appendingPathComponent("Movies"), icon: "film.fill", isSelected: false),
            ScanTargetItem(name: "Tüm Ev Dizini (~)", path: home, icon: "house.fill", isSelected: false)
        ]
        
        // Harici diskleri (/Volumes/*) dinamik tespit et
        let fm = FileManager.default
        if let volContents = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for volName in volContents {
                // Macintosh HD ve gizli mountları atla
                if volName.hasPrefix(".") || volName == "Macintosh HD" { continue }
                let volPath = "/Volumes/\(volName)"
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
    
    /// Tekli dizin için geriye dönük uyumlu tarama
    public func scanDuplicates(
        in directoryPath: String,
        minSize: Int64 = 4096
    ) async -> [DuplicateGroup] {
        return await scanDuplicates(in: [directoryPath], minSize: minSize)
    }
    
    /// Çoklu disk ve klasörler arasında Eşzamanlı Çift Dosya Tarayıcı (POSIX + 4KB Prefix/Suffix + SHA-256)
    public func scanDuplicates(
        in directories: [String],
        minSize: Int64 = 4096
    ) async -> [DuplicateGroup] {
        let validPaths = directories.filter { FileManager.default.fileExists(atPath: $0) }
        guard !validPaths.isEmpty else { return [] }
        
        // 1. Aşama: Boyut Eşleme (Tüm seçilen dizinlerde)
        let candidatesBySize = await Task.detached(priority: .userInitiated) {
            self.collectFilesBySize(inDirectories: validPaths, minSize: minSize)
        }.value
        
        guard !candidatesBySize.isEmpty else { return [] }
        
        // 2 & 3. Aşama: Prefix (4KB) ve Suffix (4KB) Hash Filtresi
        let candidatesByPartialHash = await Task.detached(priority: .userInitiated) {
            self.filterByPartialHashes(candidatesBySize: candidatesBySize)
        }.value
        
        guard !candidatesByPartialHash.isEmpty else { return [] }
        
        // 4. Aşama: Çok Çekirdekli Paralel Tam SHA-256 Doğrulama
        let fullHashGroups = await computeFullHashesConcurrently(candidates: candidatesByPartialHash)
        
        // 5. Aşama: Gruplama ve Orijinal Belirleme
        return organizeDuplicateGroups(fullHashGroups: fullHashGroups)
    }
    
    // MARK: - 1. Aşama: Boyut Toplama (Çoklu Dizin)
    private func collectFilesBySize(inDirectories dirs: [String], minSize: Int64) -> [Int64: [String]] {
        var sizeMap: [Int64: [String]] = [:]
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        let fm = FileManager.default
        var seenPaths = Set<String>()
        
        for dir in dirs {
            let rootURL = URL(fileURLWithPath: dir)
            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else { continue }
            
            while let url = enumerator.nextObject() as? URL {
                let path = url.path
                if seenPaths.contains(path) { continue }
                seenPaths.insert(path)
                
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      let size = values.fileSize,
                      Int64(size) >= minSize else { continue }
                
                let fileSize = Int64(size)
                sizeMap[fileSize, default: []].append(path)
            }
        }
        
        return sizeMap.filter { $0.value.count > 1 }
    }
    
    // MARK: - 2 & 3. Aşama: 4KB Prefix + 4KB Suffix Hash Filtresi
    private func filterByPartialHashes(candidatesBySize: [Int64: [String]]) -> [[String]] {
        var candidateClusters: [[String]] = []
        
        for (fileSize, paths) in candidatesBySize {
            var partialMap: [String: [String]] = [:]
            
            for path in paths {
                if let partialKey = computePartialKey(path: path, fileSize: fileSize) {
                    partialMap[partialKey, default: []].append(path)
                }
            }
            
            for (_, matchingPaths) in partialMap where matchingPaths.count > 1 {
                candidateClusters.append(matchingPaths)
            }
        }
        
        return candidateClusters
    }
    
    private func computePartialKey(path: String, fileSize: Int64) -> String? {
        guard let file = fopen(path, "rb") else { return nil }
        defer { fclose(file) }
        
        let chunkSize = 4096
        var prefixBuffer = [UInt8](repeating: 0, count: chunkSize)
        let prefixRead = fread(&prefixBuffer, 1, chunkSize, file)
        guard prefixRead > 0 else { return nil }
        
        var suffixBuffer = [UInt8](repeating: 0, count: chunkSize)
        var suffixRead = 0
        if fileSize > Int64(chunkSize * 2) {
            fseek(file, -chunkSize, SEEK_END)
            suffixRead = fread(&suffixBuffer, 1, chunkSize, file)
        }
        
        var hasher = SHA256()
        hasher.update(data: Data(prefixBuffer[0..<prefixRead]))
        if suffixRead > 0 {
            hasher.update(data: Data(suffixBuffer[0..<suffixRead]))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 4. Aşama: Çok Çekirdekli Paralel Tam SHA-256
    private func computeFullHashesConcurrently(candidates: [[String]]) async -> [String: (size: Int64, paths: [String])] {
        await withTaskGroup(of: (String, String, Int64)?.self) { group in
            for cluster in candidates {
                for path in cluster {
                    group.addTask {
                        guard let hash = self.computeFullSHA256(path: path) else { return nil }
                        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
                        return (hash, path, size)
                    }
                }
            }
            
            var groups: [String: (size: Int64, paths: [String])] = [:]
            for await item in group {
                guard let (hash, path, size) = item else { continue }
                if groups[hash] == nil {
                    groups[hash] = (size: size, paths: [path])
                } else {
                    groups[hash]?.paths.append(path)
                }
            }
            return groups.filter { $0.value.paths.count > 1 }
        }
    }
    
    private func computeFullSHA256(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let bufferSize = 131072 // 128 KB yüksek performanslı tampon
        while true {
            let data = handle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 5. Aşama: Gruplama ve Akıllı Orijinal Seçimi
    private func organizeDuplicateGroups(fullHashGroups: [String: (size: Int64, paths: [String])]) -> [DuplicateGroup] {
        var result: [DuplicateGroup] = []
        
        for (hash, tuple) in fullHashGroups {
            // Tarihe göre sırala: En eski dosya varsayılan orijinaldir
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
    
    // MARK: - Akıllı Karar Kuralları (Hangi Klasördekiler Korunsun)
    
    /// Belirli bir klasördeki dosyaları koru, diğer klasörlerdeki kopyaları silmek üzere seç
    public func applyFolderRetentionRule(groups: [DuplicateGroup], keepFolderPath: String) -> [DuplicateGroup] {
        return groups.map { group in
            var updatedFiles = group.files
            // Eğer bu grupta korunan klasöre ait dosya varsa
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
    
    /// Tarihe göre koruma kuralı (En eskiyi veya en yeniyi koru)
    public func applyDateRetentionRule(groups: [DuplicateGroup], keepOldest: Bool) -> [DuplicateGroup] {
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
    
    /// Klasör bazlı çift dosya raporu üretir
    public func getFolderSummaries(from groups: [DuplicateGroup]) -> [FolderDuplicateSummary] {
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
