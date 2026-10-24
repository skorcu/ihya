import Foundation
import AppKit

public struct LensNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public var children: [LensNode]
    public var percentage: Double
    public let colorHex: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64,
        children: [LensNode] = [],
        percentage: Double = 0.0,
        colorHex: String = "0EA5E9"
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
        self.percentage = percentage
        self.colorHex = colorHex
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

@MainActor
public final class SpaceLensEngine: ObservableObject {
    public static let shared = SpaceLensEngine()
    
    @Published public var rootNode: LensNode? = nil
    @Published public var currentNode: LensNode? = nil
    @Published public var pathBreadcrumbs: [LensNode] = []
    @Published public var isScanning: Bool = false
    @Published public var scanProgressMessage: String = ""
    @Published public var selectedNodeIds: Set<String> = []
    @Published public var totalScannedSize: Int64 = 0
    
    private let palette: [String] = [
        "0EA5E9", // Sky Blue
        "10B981", // Emerald
        "8B5CF6", // Violet
        "F59E0B", // Amber
        "EC4899", // Pink
        "06B6D4", // Cyan
        "F97316", // Orange
        "6366F1", // Indigo
        "14B8A6", // Teal
        "E11D48"  // Rose
    ]
    
    public init() {}
    
    /// Belirtilen dizini (veya Kullanıcı Ev Dizinini) derinlemesine tarar
    public func scan(path: String? = nil) async {
        let targetPath = path ?? FileManager.default.homeDirectoryForCurrentUser.path
        isScanning = true
        scanProgressMessage = "Dizin haritası taranıyor: \(URL(fileURLWithPath: targetPath).lastPathComponent)..."
        selectedNodeIds.removeAll()
        
        let scanned = await Task.detached(priority: .userInitiated) { [targetPath, palette] () -> LensNode in
            return Self.scanDirectory(path: targetPath, depth: 0, maxDepth: 2, palette: palette)
        }.value
        
        self.rootNode = scanned
        self.currentNode = scanned
        self.pathBreadcrumbs = [scanned]
        self.totalScannedSize = scanned.size
        self.isScanning = false
        self.scanProgressMessage = ""
    }
    
    /// Bir alt klasörün içine derinleşme (Drill Down)
    public func drillDown(to node: LensNode) {
        guard node.isDirectory else { return }
        
        // Eğer zaten çocukları taranmışsa doğrudan aç
        if !node.children.isEmpty {
            currentNode = node
            pathBreadcrumbs.append(node)
            selectedNodeIds.removeAll()
            return
        }
        
        // Henüz çocukları taranmamışsa arka planda hızlıca tara ve güncelle
        isScanning = true
        scanProgressMessage = "Klasör inceleniyor: \(node.name)..."
        selectedNodeIds.removeAll()
        
        let targetPath = node.path
        let currentBreadcrumbs = pathBreadcrumbs
        let paletteColors = palette
        
        Task {
            let scanned = await Task.detached(priority: .userInitiated) { [targetPath, paletteColors] () -> LensNode in
                return Self.scanDirectory(path: targetPath, depth: 0, maxDepth: 1, palette: paletteColors)
            }.value
            
            self.currentNode = scanned
            var newBreadcrumbs = currentBreadcrumbs
            newBreadcrumbs.append(scanned)
            self.pathBreadcrumbs = newBreadcrumbs
            self.isScanning = false
            self.scanProgressMessage = ""
        }
    }
    
    /// Kullanıcıya NSOpenPanel açarak harici disk veya özel klasör seçtirir
    public func selectAndScanFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Klasörü Tara"
        panel.message = "Hacim röntgeni çekilecek klasörü veya harici diski seçin"
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await self.scan(path: url.path)
            }
        }
    }
    
    /// Bir üst klasöre veya belirli bir ekmek kırıntısına geri dönme
    public func navigateBack(to index: Int) {
        guard index >= 0, index < pathBreadcrumbs.count else { return }
        pathBreadcrumbs = Array(pathBreadcrumbs.prefix(index + 1))
        currentNode = pathBreadcrumbs.last
        selectedNodeIds.removeAll()
    }
    
    /// Seçili öğeleri macOS Çöp Kutusuna Taşıma (100% Geri Alınabilir)
    public func recycleSelectedNodes() -> Int64 {
        guard let current = currentNode else { return 0 }
        var totalFreed: Int64 = 0
        let itemsToDelete = current.children.filter { selectedNodeIds.contains($0.id) }
        
        for item in itemsToDelete {
            guard SafetyFilter.shared.isSafeToDelete(path: item.path) else {
                continue
            }
            
            let url = URL(fileURLWithPath: item.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                totalFreed += item.size
            } catch {
                NSLog("[SpaceLens] Çöp kutusuna taşınamadı: \(item.path) - \(error.localizedDescription)")
            }
        }
        
        // Mevcut düğümü güncelle
        let remainingChildren = current.children.filter { !selectedNodeIds.contains($0.id) }
        let newSize = remainingChildren.reduce(0) { $0 + $1.size }
        var updated = current
        updated.children = remainingChildren
        self.currentNode = LensNode(
            id: updated.id,
            name: updated.name,
            path: updated.path,
            isDirectory: updated.isDirectory,
            size: newSize,
            children: remainingChildren,
            percentage: updated.percentage,
            colorHex: updated.colorHex
        )
        self.selectedNodeIds.removeAll()
        
        return totalFreed
    }
    
    // MARK: - Arka Plan Derin Tarama Algoritması
    nonisolated private static func scanDirectory(path: String, depth: Int, maxDepth: Int, palette: [String]) -> LensNode {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.isEmpty ? path : url.lastPathComponent
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
            return LensNode(name: name, path: path, isDirectory: false, size: 0)
        }
        
        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? Int64) ?? 0
            return LensNode(name: name, path: path, isDirectory: false, size: size)
        }
        
        // Klasör içeriğini listele
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return LensNode(name: name, path: path, isDirectory: true, size: 0)
        }
        
        var childNodes: [LensNode] = []
        var totalSize: Int64 = 0
        
        for item in contents {
            // Gizli sistem dosyalarını veya özel döngüleri filtrele
            if item.hasPrefix(".") && item != ".Trash" { continue }
            
            let itemPath = (path as NSString).appendingPathComponent(item)
            var itemIsDir: ObjCBool = false
            guard fm.fileExists(atPath: itemPath, isDirectory: &itemIsDir) else { continue }
            
            if itemIsDir.boolValue {
                // Klasör boyutunu recursive hesapla
                let folderSize = fastCalculateDirectorySize(itemPath)
                if folderSize > 1_000_000 { // 1 MB'tan büyükleri listeye al
                    let child = LensNode(
                        name: item,
                        path: itemPath,
                        isDirectory: true,
                        size: folderSize,
                        children: []
                    )
                    childNodes.append(child)
                    totalSize += folderSize
                }
            } else {
                let attrs = try? fm.attributesOfItem(atPath: itemPath)
                let fileSize = (attrs?[.size] as? Int64) ?? 0
                if fileSize > 1_000_000 { // 1 MB'tan büyük tekil dosyalar
                    let child = LensNode(
                        name: item,
                        path: itemPath,
                        isDirectory: false,
                        size: fileSize
                    )
                    childNodes.append(child)
                    totalSize += fileSize
                }
            }
        }
        
        // Boyuta göre azalan sırala
        childNodes.sort { $0.size > $1.size }
        
        // Yüzdelikleri ve renk paletini ata
        let calculatedTotal = max(totalSize, 1)
        for i in 0..<childNodes.count {
            let ratio = Double(childNodes[i].size) / Double(calculatedTotal)
            childNodes[i].percentage = ratio
            let color = palette[i % palette.count]
            childNodes[i] = LensNode(
                id: childNodes[i].id,
                name: childNodes[i].name,
                path: childNodes[i].path,
                isDirectory: childNodes[i].isDirectory,
                size: childNodes[i].size,
                children: childNodes[i].children,
                percentage: ratio,
                colorHex: color
            )
        }
        
        return LensNode(
            name: name,
            path: path,
            isDirectory: true,
            size: totalSize,
            children: childNodes,
            percentage: 1.0,
            colorHex: "0EA5E9"
        )
    }
    
    nonisolated private static func fastCalculateDirectorySize(_ path: String) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsPackageDescendants],
            errorHandler: nil
        ) else { return 0 }
        
        var total: Int64 = 0
        var count = 0
        
        while let url = enumerator.nextObject() as? URL {
            count += 1
            if count > 20000 { break } // Aşırı uzun döngüleri koru
            
            let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            if let size = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize {
                total += Int64(size)
            }
        }
        return total
    }
}
