import Foundation

public final class AppLipoEngine: Sendable {
    public static let shared = AppLipoEngine()
    
    public init() {}
    
    /// Sistemin Apple Silicon olup olmadığını denetler
    public var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// /Applications altındaki evrensel (Universal) uygulamaları tarar
    public func scanUniversalApps() async -> [LipoItem] {
        guard isAppleSilicon else { return [] }
        var items: [LipoItem] = []
        
        let appDirs = ["/Applications", (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for app in contents where app.hasSuffix(".app") {
                // Güvenlik ve sistem koruması: Gizli veya özel uygulamaları atla
                if app.hasPrefix(".") || app.contains("Sarkac") || app.contains("sarkac") {
                    continue
                }
                
                let appPath = (dir as NSString).appendingPathComponent(app)
                let macOSDir = (appPath as NSString).appendingPathComponent("Contents/MacOS")
                guard let binaries = try? FileManager.default.contentsOfDirectory(atPath: macOSDir) else { continue }
                
                for bin in binaries {
                    let binPath = (macOSDir as NSString).appendingPathComponent(bin)
                    if let (isUniversal, currentSize) = checkUniversalBinaryDirect(at: binPath), isUniversal {
                        let reclaimable = currentSize / 2 // x86_64 mimarisinin silinmesiyle kazanılacak tahmini alan
                        if reclaimable > 5_000_000 { // 5 MB üstü
                            items.append(LipoItem(
                                appName: (app as NSString).deletingPathExtension,
                                appPath: appPath,
                                binaryPath: binPath,
                                currentSize: currentSize,
                                reclaimableSize: reclaimable
                            ))
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    /// Mach-O Fat Binary Magic Number doğrudan dosya başlığından (header) okunur
    /// 0xCAFEBABE (FAT_MAGIC) veya 0xBEBAFECA (FAT_CIGAM)
    private func checkUniversalBinaryDirect(at path: String) -> (isUniversal: Bool, size: Int64)? {
        guard let file = fopen(path, "rb") else { return nil }
        defer { fclose(file) }
        
        var magic: UInt32 = 0
        let readCount = fread(&magic, 4, 1, file)
        guard readCount == 1 else { return nil }
        
        // Fat binary magic: 0xCAFEBABE (big endian) or 0xBEBAFECA (little endian)
        let isFat = (magic == 0xbebafeca || magic == 0xcafebabe || magic == 0xbfbabeca || magic == 0xcafebabf)
        guard isFat else { return nil }
        
        // Boyutu al
        fseek(file, 0, SEEK_END)
        let fileSize = ftell(file)
        guard fileSize > 0 else { return nil }
        
        return (true, Int64(fileSize))
    }
}
