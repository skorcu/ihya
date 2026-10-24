import AppKit
import SwiftUI

public final class LegalNoticeWindow: NSWindowController {
    public static let shared = LegalNoticeWindow()
    
    private var windowInstance: NSWindow?
    
    public init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func showIfNeeded(completion: @escaping () -> Void) {
        let hasAccepted = UserDefaults.standard.bool(forKey: "ihya_has_accepted_legal_terms")
        if hasAccepted {
            completion()
            return
        }
        
        let contentView = LegalNoticeView { [weak self] in
            self?.close()
            completion()
        }
        
        let hosting = NSHostingView(rootView: contentView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "İhyâ — Güvenlik Güvencesi ve Yasal Sorumluluk Beyanı"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        
        self.windowInstance = window
        self.window = window
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
