import AppKit
import QuickLookUI

@MainActor
public final class QuickLookHelper: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = QuickLookHelper()
    
    public private(set) var currentPreviewURL: URL?
    
    private override init() {
        super.init()
    }
    
    public func preview(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        
        // Eğer zaten bu dosya açıksa kapat (Toggle)
        if let panel = QLPreviewPanel.shared(), panel.isVisible && currentPreviewURL == url {
            panel.orderOut(nil)
            currentPreviewURL = nil
            return
        }
        
        currentPreviewURL = url
        
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        } else {
            // Güvenli sistem varsayılanıyla aç
            NSWorkspace.shared.open(url)
        }
    }
    
    public func closePreview() {
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
            currentPreviewURL = nil
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    nonisolated public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return MainActor.assumeIsolated {
            QuickLookHelper.shared.currentPreviewURL != nil ? 1 : 0
        }
    }
    
    nonisolated public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return MainActor.assumeIsolated {
            QuickLookHelper.shared.currentPreviewURL as NSURL?
        }
    }
}
