import AppKit
import SwiftUI
import IhyaCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        setupPopover()
        
        // Cihaz telemetri ve canlı HWID lisans senkronizasyonu
        TelemetryManager.shared.sendHeartbeat()
        
        // Merkezi Sürüm & Otomatik Güncelleme Motoru (3 sn sonra başlar)
        IhyaUpdateChecker.shared.startPeriodicChecks()
        
        LegalNoticeWindow.shared.showIfNeeded { [weak self] in
            Task { @MainActor in
                self?.openMainWindow()
            }
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "İhyâ")
            button.toolTip = "İhyâ — macOS Arınma & Canlanma Sistemi"
            button.action = #selector(statusBarClicked)
            button.target = self
        }
    }
    
    private func setupPopover() {
        let islandView = MenuBarIslandView(
            onOpenMainWindow: { [weak self] in
                self?.popover?.performClose(nil)
                self?.openMainWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 285, height: 325)
        pop.contentViewController = NSHostingController(rootView: islandView)
        self.popover = pop
    }
    
    @objc private func statusBarClicked() {
        guard let button = statusItem?.button, let pop = popover else {
            openMainWindow()
            return
        }
        
        if pop.isShown {
            pop.performClose(nil)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = MainView()
        let hosting = NSHostingView(rootView: contentView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1140, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        if let primaryScreen = NSScreen.screens.first {
            let vis = primaryScreen.visibleFrame
            let x = vis.origin.x + max(20, (vis.width - 1140) / 2)
            let y = vis.origin.y + max(20, (vis.height - 720) / 2)
            win.setFrame(NSRect(x: x, y: y, width: 1140, height: 720), display: true)
        } else {
            win.center()
        }
        win.title = ""
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.contentView = hosting
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 960, height: 600)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
