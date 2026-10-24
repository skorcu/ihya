import SwiftUI
import AppKit
import Combine
import IhyaCore

public struct SystemOptimizationView: View {
    @StateObject private var engine = SystemOptimizationEngine.shared
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    @State private var appToQuit: AppMemoryUsage? = nil
    @State private var showQuitConfirm: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Sabit Üst Başlık & Eylem Çubuğu (Asla Altta Kalmaz)
            headerBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // MARK: - 2. Kaydırılabilir İçerik
            ScrollView {
                VStack(spacing: 20) {
                    // Üst Bölüm: Bellek Çarkı + Canlı İlk 5 Tüketici (Yan Yana)
                    HStack(alignment: .top, spacing: 16) {
                        memoryGaugeCard
                            .frame(maxWidth: .infinity)
                        
                        topMemoryConsumersCard
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Akıllı Bellek Tavsiyesi Banner'ı (Kullanıcı Talebi: Yüksek RAM tüketenleri tespit edip kapatma önerisi)
                    if let topApp = engine.topMemoryHogs.first, engine.memoryStats.usagePercentage >= 60.0 {
                        smartAdvisorBanner(topApp: topApp)
                    }
                    
                    // Alt Bölüm: 6 Derin Sistem Arındırma Görevi (2 Sütunlu Grid)
                    tasksGridSection
                }
                .padding(24)
            }
        }
        .onReceive(timer) { _ in
            if !engine.isOptimizing {
                engine.refreshMemoryStats()
            }
        }
        .alert(isPresented: $showQuitConfirm) {
            Alert(
                title: Text("\(appToQuit?.name ?? "Uygulama") Kapatılsın mı?"),
                message: Text("Bu uygulamayı sonlandırarak \(appToQuit?.formattedMemory ?? "") belleği anında serbest bırakabilirsiniz. Kaydedilmemiş değişiklikler kaybolabilir."),
                primaryButton: .destructive(Text("Uygulamayı Kapat")) {
                    if let app = appToQuit {
                        engine.terminateApp(pid: app.id)
                        SoundManager.shared.playSuccessChime()
                    }
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // MARK: - Sabit Üst Başlık & Sağ Eylem Butonu
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sistem & Bellek Röntgeni")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                if engine.isOptimizing && !engine.currentActionText.isEmpty {
                    Text(engine.currentActionText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "2DD4BF"))
                } else {
                    Text("Birleşik RAM Durumu, Canlı Süreçler & Çekirdek Sistem Optimizasyonu")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Üst Sağda Daima Görünür Arındır Butonu (Asla Altta Gizlenmez)
            Button(action: {
                Task {
                    await engine.runAllOptimizations()
                    SoundManager.shared.playSuccessChime()
                    HapticManager.shared.generateSuccessFeedback()
                }
            }) {
                HStack(spacing: 7) {
                    if engine.isOptimizing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Arındırılıyor...")
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Sistem & Belleği Arındır")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "14B8A6"), Color(hex: "0D9488")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color(hex: "14B8A6").opacity(0.35), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(engine.isOptimizing)
        }
    }
    
    // MARK: - Canlı Bellek Gösterge Kartı (RAM Gauge)
    private var memoryGaugeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "2DD4BF"))
                Text("Fiziksel Birleşik Bellek")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Toplam: \(engine.memoryStats.formattedTotal)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            HStack(alignment: .center, spacing: 16) {
                // Dairesel Gösterge
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 74, height: 74)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(engine.memoryStats.usagePercentage / 100.0))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "5EEAD4"), Color(hex: "0D9488")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: -90))
                        .frame(width: 74, height: 74)
                        .animation(.easeInOut(duration: 0.4), value: engine.memoryStats.usagePercentage)
                    
                    VStack(spacing: 0) {
                        Text("%\(Int(engine.memoryStats.usagePercentage))")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Kullanım")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                
                // Dağılım İstatistikleri
                VStack(alignment: .leading, spacing: 6) {
                    statRow(title: "Kullanılan", value: engine.memoryStats.formattedUsed, color: Color(hex: "14B8A6"))
                    statRow(title: "Serbest", value: engine.memoryStats.formattedFree, color: Color.white.opacity(0.5))
                    statRow(title: "İnaktif", value: ByteCountFormatter.string(fromByteCount: Int64(engine.memoryStats.inactiveBytes), countStyle: .memory), color: Color(hex: "06B6D4"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Yatay Dağılım Çubuğu
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color(hex: "14B8A6"))
                        .frame(width: geo.size.width * CGFloat(engine.memoryStats.usagePercentage / 100.0))
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                }
                .cornerRadius(3)
            }
            .frame(height: 5)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func statRow(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    // MARK: - En Çok RAM Tüketen 5 Uygulama (Canlı Bellek Tüketicileri)
    private var topMemoryConsumersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("En Çok RAM Tüketen 5 Uygulama")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Canlı")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "10B981").opacity(0.2))
                    .foregroundColor(Color(hex: "34D399"))
                    .cornerRadius(4)
            }
            
            if engine.topMemoryHogs.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    ProgressView().scaleEffect(0.6)
                    Text("Bellek süreçleri taranıyor...")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                VStack(spacing: 6) {
                    ForEach(engine.topMemoryHogs) { app in
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .cornerRadius(4)
                            } else {
                                Image(systemName: "app.dashed")
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Text(app.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(app.formattedMemory)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "38BDF8"))
                            
                            Text("%\(String(format: "%.1f", app.percentageOfRAM))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 32, alignment: .trailing)
                            
                            // Hızlı Kapat / Sonlandır Butonu
                            Button(action: {
                                appToQuit = app
                                showQuitConfirm = true
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .help("\(app.name) uygulamasını kapatarak belleği serbest bırak")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Akıllı Bellek Tavsiyesi Banner'ı (Smart RAM Advisor - Net ve İlk Bakışta Okunabilir)
    private func smartAdvisorBanner(topApp: AppMemoryUsage) -> some View {
        HStack(spacing: 14) {
            // 1. Uygulama Simgesi / Aydınlatma Rozeti
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F59E0B").opacity(0.16))
                    .frame(width: 44, height: 44)
                
                if let icon = topApp.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                } else {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "F59E0B"))
                }
            }
            
            // 2. Başlık & Açıklama (Uygulama Adı İlk Satırda ve En Belirgin Şekilde)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(topApp.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                    
                    Text(topApp.formattedMemory)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: "EF4444").opacity(0.25))
                        .foregroundColor(Color(hex: "F87171"))
                        .cornerRadius(5)
                    
                    Text("%\(Int(engine.memoryStats.usagePercentage)) Dolu")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F59E0B").opacity(0.2))
                        .foregroundColor(Color(hex: "FCD34D"))
                        .cornerRadius(4)
                }
                
                Text("Arka planda yüksek RAM tüketiyor. Kapatıp sistemi anında ferahlatmak ister misiniz?")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 3. Tek Tıkla Kapatma Eylemi
            Button(action: {
                appToQuit = topApp
                showQuitConfirm = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text("\(topApp.name)'ı Kapat")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color(hex: "EF4444").opacity(0.4), radius: 5, y: 1)
            }
            .buttonStyle(.plain)
            .help("\(topApp.name) uygulamasını sonlandırarak \(topApp.formattedMemory) belleği serbest bırak")
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "F59E0B").opacity(0.14), Color(hex: "D97706").opacity(0.06)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "F59E0B").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 6 Derin Sistem Arındırma Görevi (2 Sütunlu Kompakt Grid)
    private var tasksGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ÇEKİRDEK SİSTEM VE ÖNBELLEK ARINDIRMA")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .padding(.leading, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(engine.tasks) { task in
                    taskCard(task)
                }
            }
        }
    }
    
    private func taskCard(_ task: OptimizationTask) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "14B8A6").opacity(0.18))
                    .frame(width: 34, height: 34)
                
                Image(systemName: task.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "2DD4BF"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(task.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if task.isCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "10B981"))
                        .font(.system(size: 12))
                    
                    Text(task.freedText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "10B981"))
                        .lineLimit(1)
                }
            } else if engine.isOptimizing {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Text("Hazır")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
