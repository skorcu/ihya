import Foundation

public final class FastScanner: Sendable {
    public static let shared = FastScanner()
    
    public init() {}
    
    /// Bir klasörün gerçek disk boyutunu POSIX seviyesinde hesaplar
    public func calculateDirectorySize(at path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        
        var totalSize: Int64 = 0
        let url = URL(fileURLWithPath: path)
        
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey, .isPackageKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
            if values.isDirectory != true {
                totalSize += Int64(values.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    /// Bir dosyanın veya klasörün boyutunu döner
    public func getPathSize(path: String) -> Int64 {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                return calculateDirectorySize(at: path)
            } else {
                let attrs = try? FileManager.default.attributesOfItem(atPath: path)
                return attrs?[.size] as? Int64 ?? 0
            }
        }
        return 0
    }
}
