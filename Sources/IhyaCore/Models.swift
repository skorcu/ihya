import Foundation

public enum CleanCategoryType: String, CaseIterable, Identifiable, Sendable {
    case systemJunk = "system_junk"
    case browserCaches = "browser_caches"
    case appResidues = "app_residues"
    case developerVault = "developer_vault"
    case trashBins = "trash_bins"
    case duplicateFiles = "duplicate_files"
    case ghostDaemons = "ghost_daemons"
    case appLipo = "app_lipo"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .systemJunk: return "Sistem Çöpleri"
        case .browserCaches: return "Tarayıcı & Web Kasası"
        case .appResidues: return "Uygulama Artıkları"
        case .developerVault: return "Geliştirici Kasası"
        case .trashBins: return "Çöp Sepeti"
        case .duplicateFiles: return "Çift Dosyalar"
        case .ghostDaemons: return "Hayalet Servisler"
        case .appLipo: return "Mimari İnceltici"
        }
    }
    
    public var icon: String {
        switch self {
        case .systemJunk: return "sparkles"
        case .browserCaches: return "globe"
        case .appResidues: return "shippingbox.and.arrow.backward"
        case .developerVault: return "hammer.fill"
        case .trashBins: return "trash.fill"
        case .duplicateFiles: return "doc.on.doc.fill"
        case .ghostDaemons: return "bolt.slash.fill"
        case .appLipo: return "scissors"
        }
    }
    
    public var isCoreSmartClean: Bool {
        switch self {
        case .systemJunk, .browserCaches, .appResidues, .developerVault, .trashBins:
            return true
        default:
            return false
        }
    }
}

public enum SafetyLevel: String, Sendable {
    case safe = "safe"
    case caution = "caution"
    case developer = "developer"
    case protected = "protected"
    
    public var displayName: String {
        switch self {
        case .safe: return "Güvenli"
        case .caution: return "Dikkat"
        case .developer: return "Geliştirici"
        case .protected: return "Korumalı"
        }
    }
}

public struct CleanItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let category: CleanCategoryType
    public let safety: SafetyLevel
    public let itemDescription: String
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        size: Int64,
        category: CleanCategoryType,
        safety: SafetyLevel = .safe,
        itemDescription: String = "",
        isSelected: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.category = category
        self.safety = safety
        self.itemDescription = itemDescription
        self.isSelected = isSelected
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct CategorySummary: Identifiable, Sendable {
    public let category: CleanCategoryType
    public var totalSize: Int64
    public var items: [CleanItem]
    public var isEnabled: Bool
    
    public var id: String { category.rawValue }
    
    public init(category: CleanCategoryType, totalSize: Int64 = 0, items: [CleanItem] = [], isEnabled: Bool = true) {
        self.category = category
        self.totalSize = totalSize
        self.items = items
        self.isEnabled = isEnabled
    }
    
    public var formattedSize: String {
        if totalSize == 0 {
            return "Taramaya Hazır"
        }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: String
    public let fileSize: Int64
    public let sha256: String
    public var files: [DuplicateFile]
    
    public init(id: String = UUID().uuidString, fileSize: Int64, sha256: String, files: [DuplicateFile]) {
        self.id = id
        self.fileSize = fileSize
        self.sha256 = sha256
        self.files = files
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var reclaimableSize: Int64 {
        let count = files.filter { $0.isSelectedForDeletion }.count
        return Int64(count) * fileSize
    }
    
    public var formattedReclaimable: String {
        ByteCountFormatter.string(fromByteCount: reclaimableSize, countStyle: .file)
    }
    
    /// Dosya isimleri farklı olmasına rağmen içeriği aynı mı?
    public var isDifferentNames: Bool {
        let names = Set(files.map { $0.name })
        return names.count > 1
    }
    
    /// Bu çiftlerin yer aldığı benzersiz klasörler
    public var uniqueFolders: [String] {
        Array(Set(files.map { ($0.path as NSString).deletingLastPathComponent })).sorted()
    }
}

public struct DuplicateFile: Identifiable, Sendable {
    public let id: String
    public let path: String
    public let name: String
    public let modifiedDate: Date
    public var isOriginal: Bool
    public var isSelectedForDeletion: Bool
    
    public init(
        id: String = UUID().uuidString,
        path: String,
        name: String,
        modifiedDate: Date = Date(),
        isOriginal: Bool = false,
        isSelectedForDeletion: Bool = false
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.modifiedDate = modifiedDate
        self.isOriginal = isOriginal
        self.isSelectedForDeletion = isSelectedForDeletion
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
}

public struct GhostDaemonItem: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let plistPath: String
    public let missingBinaryPath: String
    public let isUserAgent: Bool
    
    public init(id: String = UUID().uuidString, label: String, plistPath: String, missingBinaryPath: String, isUserAgent: Bool) {
        self.id = id
        self.label = label
        self.plistPath = plistPath
        self.missingBinaryPath = missingBinaryPath
        self.isUserAgent = isUserAgent
    }
}

public struct LipoItem: Identifiable, Sendable {
    public let id: String
    public let appName: String
    public let appPath: String
    public let binaryPath: String
    public let currentSize: Int64
    public let reclaimableSize: Int64
    public var isSelected: Bool
    
    public init(
        id: String = UUID().uuidString,
        appName: String,
        appPath: String,
        binaryPath: String,
        currentSize: Int64,
        reclaimableSize: Int64,
        isSelected: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.appPath = appPath
        self.binaryPath = binaryPath
        self.currentSize = currentSize
        self.reclaimableSize = reclaimableSize
        self.isSelected = isSelected
    }
    
    public var formattedReclaimable: String {
        ByteCountFormatter.string(fromByteCount: reclaimableSize, countStyle: .file)
    }
}
