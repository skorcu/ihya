import SwiftUI
import AppKit
import Combine
import IhyaCore

public struct SystemOptimizationView: View {
    @StateObject private var engine = SystemOptimizationEngine.shared
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Üst Bellek Röntgeni (RAM Pressure & Live Breakdown)
                memoryGaugeCard
                
                // 2. Optimizasyon Görevleri Listesi
                tasksListSection
                
                // 3. Alt Eylem Butonu
                actionSection
            }
            .padding(24)
        }
        .onReceive(timer) { _ in
            if !engine.isOptimizing {
                engine.refreshMemoryStats()
            }
        }
    }
    
    // MARK: - Canlı Bellek Gösterge Kartı (RAM Gauge)
    private var memoryGaugeCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 20) {
                // Sol Dairesel RAM Çemberi
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(engine.memoryStats.usagePercentage / 100.0))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "5EEAD4"), Color(hex: "0D9488")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: -90))
                        .frame(width: 90, height: 90)
                        .animation(.easeInOut(duration: 0.5), value: engine.memoryStats.usagePercentage)
                    
                    VStack(spacing: 0) {
                        Text("%\(Int(engine.memoryStats.usagePercentage))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Kullanım")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                
                // Sağ Detaylı Bellek Dağılımı
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Fiziksel Birleşik Bellek (Unified RAM)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Toplam: \(engine.memoryStats.formattedTotal)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Yatay Renkli Dağılım Çubuğu
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            // Aktif (Wired + Active)
                            Rectangle()
                                .fill(Color(hex: "14B8A6"))
                                .frame(width: geo.size.width * CGFloat(engine.memoryStats.usagePercentage / 100.0))
                            
                            // Serbest (Free + Inactive)
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 6)
                    
                    HStack(spacing: 16) {
                        statIndicator(title: "Kullanılan", value: engine.memoryStats.formattedUsed, color: Color(hex: "14B8A6"))
                        statIndicator(title: "Serbest", value: engine.memoryStats.formattedFree, color: Color.white.opacity(0.5))
                        statIndicator(title: "İnaktif", value: ByteCountFormatter.string(fromByteCount: Int64(engine.memoryStats.inactiveBytes), countStyle: .memory), color: Color(hex: "06B6D4"))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func statIndicator(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
    
    // MARK: - Optimizasyon Görevleri Listesi
    private var tasksListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DERİN SİSTEM ARINDIRMA")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.leading, 4)
            
            VStack(spacing: 8) {
                ForEach(engine.tasks) { task in
                    taskRow(task)
                }
            }
        }
    }
    
    private func taskRow(_ task: OptimizationTask) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "14B8A6").opacity(0.18))
                    .frame(width: 36, height: 36)
                
                Image(systemName: task.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "2DD4BF"))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(task.description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if task.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "10B981"))
                        .font(.system(size: 13))
                    
                    Text(task.freedText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "10B981"))
                }
            } else if engine.isOptimizing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Text("Hazır")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Alt Eylem Butonu
    private var actionSection: some View {
        VStack(spacing: 12) {
            if !engine.currentActionText.isEmpty {
                Text(engine.currentActionText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "2DD4BF"))
            }
            
            FloatingActionButton(
                title: engine.isOptimizing ? "Sistem Arındırılıyor..." : "Sistem & Belleği Arındır",
                icon: "bolt.fill",
                shortcutHint: "⌘↩",
                isPulsing: !engine.isOptimizing,
                colorStyle: .freshMint
            ) {
                Task {
                    await engine.runAllOptimizations()
                    SoundManager.shared.playSuccessChime()
                    HapticManager.shared.generateSuccessFeedback()
                }
            }
        }
        .padding(.top, 8)
    }
}
