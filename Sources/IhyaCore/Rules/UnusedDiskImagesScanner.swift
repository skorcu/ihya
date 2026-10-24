import Foundation

public final class UnusedDiskImagesScanner: Sendable {
    public static let shared = UnusedDiskImagesScanner()
    
    public init() {}
    
    public func scanUnusedImages() async -> [CleanItem] {
        var items: [CleanItem] = []
        let home = NSHomeDirectory()
        let downloadsPath = (home as NSString).appendingPathComponent("Downloads")
        
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: downloadsPath) else {
            return []
        }
        
        let extensions = [".dmg", ".pkg", ".iso", ".xip"]
        
        for file in contents {
            let lower = file.lowercased()
            if extensions.contains(where: { lower.hasSuffix($0) }) {
                let fullPath = (downloadsPath as NSString).appendingPathComponent(file)
                let size = FastScanner.shared.getPathSize(path: fullPath)
                if size > 5_000_000 { // 5 MB üstü
                    items.append(CleanItem(
                        name: file,
                        path: fullPath,
                        size: size,
                        category: .systemJunk,
                        safety: .safe,
                        itemDescription: "Kullanılmış ve unutulmuş disk kalıbı / kurulum paketi"
                    ))
                }
            }
        }
        
        return items
    }
}
