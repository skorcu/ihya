import Foundation

public struct MediaInventoryStats: Sendable {
    public var imagesCount: Int = 0
    public var imagesSize: Int64 = 0
    
    public var videosCount: Int = 0
    public var videosSize: Int64 = 0
    
    public var audioCount: Int = 0
    public var audioSize: Int64 = 0
    
    public var documentsCount: Int = 0
    public var documentsSize: Int64 = 0
    
    public var installersCount: Int = 0
    public var installersSize: Int64 = 0
    
    public var duplicatesCount: Int = 0
    public var duplicatesReclaimableSize: Int64 = 0
    
    public init() {}
    
    public var formattedImagesSize: String {
        ByteCountFormatter.string(fromByteCount: imagesSize, countStyle: .file)
    }
    
    public var formattedVideosSize: String {
        ByteCountFormatter.string(fromByteCount: videosSize, countStyle: .file)
    }
    
    public var formattedAudioSize: String {
        ByteCountFormatter.string(fromByteCount: audioSize, countStyle: .file)
    }
    
    public var formattedDocumentsSize: String {
        ByteCountFormatter.string(fromByteCount: documentsSize, countStyle: .file)
    }
    
    public var formattedInstallersSize: String {
        ByteCountFormatter.string(fromByteCount: installersSize, countStyle: .file)
    }
    
    public var formattedDuplicatesSize: String {
        ByteCountFormatter.string(fromByteCount: duplicatesReclaimableSize, countStyle: .file)
    }
}

public final class SystemMediaInventory: Sendable {
    public static let shared = SystemMediaInventory()
    
    public init() {}
    
    /// Kullanıcının ana klasörlerinde (Resimler, Videolar, Müzik, Belgeler, İndirilenler, Masaüstü) hızlı envanter çıkarır
    public func scanInventory(duplicateGroups: [DuplicateGroup] = []) async -> MediaInventoryStats {
        var stats = MediaInventoryStats()
        let home = NSHomeDirectory()
        let fm = FileManager.default
        
        // Çift kayıt verilerini doğrudan bağla
        stats.duplicatesCount = duplicateGroups.reduce(0) { $0 + max(0, $1.files.count - 1) }
        stats.duplicatesReclaimableSize = duplicateGroups.reduce(0) { $0 + $1.reclaimableSize }
        
        let targetDirs = [
            (home as NSString).appendingPathComponent("Pictures"),
            (home as NSString).appendingPathComponent("Movies"),
            (home as NSString).appendingPathComponent("Music"),
            (home as NSString).appendingPathComponent("Documents"),
            (home as NSString).appendingPathComponent("Downloads"),
            (home as NSString).appendingPathComponent("Desktop")
        ]
        
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        
        for dir in targetDirs {
            let url = URL(fileURLWithPath: dir)
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else { continue }
            
            while let fileURL = enumerator.nextObject() as? URL {
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      let size = values.fileSize else { continue }
                
                let ext = fileURL.pathExtension.lowercased()
                let sz = Int64(size)
                
                switch ext {
                case "jpg", "jpeg", "png", "webp", "heic", "gif", "svg", "tiff", "bmp", "raw", "cr2", "nef":
                    stats.imagesCount += 1
                    stats.imagesSize += sz
                case "mp4", "mov", "mkv", "avi", "m4v", "wmv", "flv", "webm":
                    stats.videosCount += 1
                    stats.videosSize += sz
                case "mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff":
                    stats.audioCount += 1
                    stats.audioSize += sz
                case "pdf", "docx", "doc", "xlsx", "xls", "pptx", "txt", "md", "rtf", "pages", "numbers", "key":
                    stats.documentsCount += 1
                    stats.documentsSize += sz
                case "dmg", "pkg", "iso":
                    stats.installersCount += 1
                    stats.installersSize += sz
                default:
                    break
                }
            }
        }
        
        return stats
    }
}
