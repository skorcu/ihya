import Foundation

public struct FileHashRecord: Codable, Sendable {
    public let path: String
    public let mtime: Double
    public let size: Int64
    public let partialKey: String
    public let fullSHA256: String?
    
    public init(path: String, mtime: Double, size: Int64, partialKey: String, fullSHA256: String? = nil) {
        self.path = path
        self.mtime = mtime
        self.size = size
        self.partialKey = partialKey
        self.fullSHA256 = fullSHA256
    }
}

public actor DuplicateHashCache {
    public static let shared = DuplicateHashCache()
    
    private var cache: [String: FileHashRecord] = [:]
    private var isDirty: Bool = false
    private let cacheFileURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("com.caneser.ihya", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("duplicate_hash_cache.json")
        self.cacheFileURL = fileURL
        self.cache = Self.loadFromDisk(at: fileURL)
    }
    
    private static func loadFromDisk(at url: URL) -> [String: FileHashRecord] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: FileHashRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }
    
    public func saveToDisk() {
        guard isDirty else { return }
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
        isDirty = false
    }
    
    public func getRecord(path: String, currentMTime: Double, currentSize: Int64) -> FileHashRecord? {
        guard let record = cache[path] else { return nil }
        if abs(record.mtime - currentMTime) < 0.001 && record.size == currentSize {
            return record
        }
        return nil
    }
    
    public func setPartial(path: String, mtime: Double, size: Int64, partialKey: String) {
        if let existing = cache[path], abs(existing.mtime - mtime) < 0.001 && existing.size == size {
            cache[path] = FileHashRecord(path: path, mtime: mtime, size: size, partialKey: partialKey, fullSHA256: existing.fullSHA256)
        } else {
            cache[path] = FileHashRecord(path: path, mtime: mtime, size: size, partialKey: partialKey, fullSHA256: nil)
        }
        isDirty = true
    }
    
    public func setFullSHA256(path: String, mtime: Double, size: Int64, partialKey: String, fullSHA256: String) {
        cache[path] = FileHashRecord(path: path, mtime: mtime, size: size, partialKey: partialKey, fullSHA256: fullSHA256)
        isDirty = true
    }
    
    public func purgeMissingFiles() {
        let fm = FileManager.default
        var purged = 0
        for (path, _) in cache {
            if !fm.fileExists(atPath: path) {
                cache.removeValue(forKey: path)
                purged += 1
            }
        }
        if purged > 0 { isDirty = true }
    }
}
