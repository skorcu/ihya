import SwiftUI
import AppKit
import Combine
import IhyaCore

public struct MenuBarIslandView: View {
    @StateObject private var optEngine = SystemOptimizationEngine.shared
    @State private var trashSizeText: String = "Hesaplanıyor..."
    @State private var trashBytes: Int64 = 0
    @State private var diskUsageText: String = "Hesaplanıyor..."
    @State private var diskUsagePercent: Double = 0.0
    @State private var isPurgingRAM: Bool = false
    @State private var statusNote: String = ""
    @State private var timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    let onOpenMainWindow: () -> Void
    let onQuit: () -> Void
    
    public init(onOpenMainWindow: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenMainWindow = onOpenMainWindow
        self.onQuit = onQuit
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Başlık & Logo
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hex: "10B981"))
                    .font(.system(size: 14, weight: .bold))
                
                Text("İhyâ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6.0")")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Button(action: onQuit) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
                .help("İhyâ'dan Çık")
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // 1. RAM Göstergesi & Hızlı Boşaltma
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Birleşik Bellek (RAM)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("%\(Int(optEngine.memoryStats.usagePercentage))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "2DD4BF"))
                }
                
                // İlerleme Çubuğu
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "5EEAD4"), Color(hex: "0D9488")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(optEngine.memoryStats.usagePercentage / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("\(optEngine.memoryStats.formattedUsed) / \(optEngine.memoryStats.formattedTotal)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            isPurgingRAM = true
                            let freed = await optEngine.purgeMemory()
                            isPurgingRAM = false
                            statusNote = freed > 0
                                ? "+\(ByteCountFormatter.string(fromByteCount: Int64(freed), countStyle: .memory)) serbest bırakıldı"
                                : "RAM zaten optimize"
                            SoundManager.shared.playSuccessChime()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isPurgingRAM {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                            }
                            Text("RAM Rahatlat")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "0D9488"))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            // 2. Disk Depolama Durumu
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "internaldrive.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "38BDF8"))
                        Text("Macintosh HD")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("%\(Int(diskUsagePercent)) Dolu")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "38BDF8"))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "38BDF8"), Color(hex: "0284C7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(diskUsagePercent / 100.0), height: 5)
                    }
                }
                .frame(height: 5)
                
                Text(diskUsageText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            // 3. Çöp Sepeti Durumu
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundColor(trashBytes > 0 ? Color(hex: "EF4444") : .white.opacity(0.4))
                    .font(.system(size: 13))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Çöp Sepeti")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Text(trashSizeText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                if trashBytes > 0 {
                    Button(action: emptyTrash) {
                        Text("Boşalt")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "EF4444").opacity(0.8))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
            
            if !statusNote.isEmpty {
                Text(statusNote)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "2DD4BF"))
            }
            
            // 3. Ana Pencereyi Aç Düğmesi
            Button(action: onOpenMainWindow) {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 12))
                    Text("İhyâ Ana Penceresini Aç")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundColor(.white)
                .background(Color.white.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .frame(width: 285)
        .background(Color(hex: "18181B"))
        .onAppear {
            optEngine.refreshMemoryStats()
            calculateTrashSize()
            calculateDiskUsage()
        }
        .onReceive(timer) { _ in
            if !isPurgingRAM {
                optEngine.refreshMemoryStats()
            }
        }
    }
    
    private func calculateDiskUsage() {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            let total = Int64(values.volumeTotalCapacity ?? 1)
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            let used = total > free ? total - free : 0
            let percent = Double(used) / Double(max(total, 1)) * 100.0
            let freeStr = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            let totalStr = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            self.diskUsagePercent = percent
            self.diskUsageText = "\(freeStr) Boş / \(totalStr)"
        }
    }
    
    private func calculateTrashSize() {
        Task.detached(priority: .background) {
            let fm = FileManager.default
            let trashPath = (NSHomeDirectory() as NSString).appendingPathComponent(".Trash")
            guard let files = try? fm.contentsOfDirectory(atPath: trashPath) else {
                await MainActor.run {
                    self.trashSizeText = "Boş"
                    self.trashBytes = 0
                }
                return
            }
            
            var total: Int64 = 0
            for file in files {
                let p = (trashPath as NSString).appendingPathComponent(file)
                if let attrs = try? fm.attributesOfItem(atPath: p),
                   let s = attrs[.size] as? Int64 {
                    total += s
                }
            }
            
            await MainActor.run {
                self.trashBytes = total
                self.trashSizeText = total > 0
                    ? ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
                    : "Boş"
            }
        }
    }
    
    private func emptyTrash() {
        let script = "tell application \"Finder\" to empty trash"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            calculateTrashSize()
            SoundManager.shared.playSuccessChime()
        }
    }
}
