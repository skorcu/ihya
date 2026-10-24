import SwiftUI
import AppKit
import IhyaCore

public struct AppUpdaterView: View {
    @ObservedObject private var engine = CleanerEngine.shared
    @ObservedObject private var updaterEngine = AppUpdaterEngine.shared
    @State private var updates: [AppUpdateItem] = []
    @State private var totalAppsCount: Int = 0
    @State private var isScanning: Bool = false
    @State private var hasScanned: Bool = false
    @State private var searchQuery: String = ""
    @State private var selectedTab: Int = 0 // 0: Güncellemeler, 1: Tüm Uygulamalar
    @State private var statusToast: String? = nil
    
    public init() {}
    
    private var filteredUpdates: [AppUpdateItem] {
        if searchQuery.isEmpty { return updates }
        return updates.filter {
            $0.appName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.currentVersion.localizedCaseInsensitiveContains(searchQuery) ||
            $0.latestVersion.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Üst Kontrol ve Başlık Barı
            headerBar
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            if isScanning {
                scanningView
            } else if !hasScanned {
                idleHeroView
            } else {
                resultsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            if !engine.availableUpdates.isEmpty {
                self.updates = engine.availableUpdates
                self.totalAppsCount = engine.totalInstalledAppsCount
                self.hasScanned = true
            } else if !hasScanned {
                startScan()
            }
        }
    }
    
    // MARK: - 1. Üst Başlık Barı
    private var headerBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "38BDF8"))
                    
                    Text("Yazılım Güncelleyici")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if hasScanned {
                        Text("\(updates.count) Güncelleme")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(updates.isEmpty ? Color.green.opacity(0.2) : Color.blue.opacity(0.25))
                            .foregroundColor(updates.isEmpty ? .green : Color(hex: "38BDF8"))
                            .cornerRadius(10)
                    }
                }
                
                Text(hasScanned ? "Mac'inizde \(totalAppsCount) uygulama tarandı. Yazılımlarınızın en son sürümleri denetlendi." : "Uygulamalarınızın Sparkle ve paket güncellemelerini tek merkezden yönetin.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Arama Kutusu
            if hasScanned && !updates.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("Uygulama ara...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 140)
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            
            // Yeniden Tara Butonu
            Button(action: { startScan() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Yeniden Tara")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
    
    // MARK: - 2. Boşta / Hero Durumu
    private var idleHeroView: some View {
        HeroStageView(
            title: "Yazılım Güncelleyici",
            subtitle: "Mac'inizdeki tüm uygulamaları tarayarak en yeni sürümleri, güvenlik yamalarını ve yeni özellikleri tek tıkla edinin.",
            emblemStyle: .sapphire,
            emblemIcon: "arrow.triangle.2.circlepath",
            bullets: [
                HeroStageView.BulletItem(
                    icon: "sparkles",
                    title: "Evrensel Besleme & Sparkle Taraması",
                    description: "Uygulamaların resmi appcast beslemelerini ve sürüm notlarını anlık karşılaştırır."
                ),
                HeroStageView.BulletItem(
                    icon: "shippingbox.fill",
                    title: "Homebrew Cask Desteği",
                    description: "Geliştirici araçlarının ve terminal paketlerinin güncel sürümlerini tespit eder."
                ),
                HeroStageView.BulletItem(
                    icon: "shield.lefthalf.filled",
                    title: "Sıfır Riskli Güncelleme",
                    description: "Resmi geliştirici adreslerinden doğrudan güvenli indirme sağlar."
                )
            ],
            targetDiskInfo: " Macintosh HD · /Applications",
            buttonTitle: "Güncellemeleri Denetle",
            buttonColorStyle: .sapphireBlue,
            isPulsing: true
        ) {
            startScan()
        }
    }
    
    // MARK: - 3. Taranıyor Durumu
    private var scanningView: some View {
        LuxuryScanningStageView(
            title: "Uygulama Güncellemeleri Denetleniyor...",
            subtitle: "Mac'inizdeki yüklü uygulamalar taranıyor ve geliştirici sunucularından son sürümler doğrulanıyor.",
            emblemStyle: .sapphire,
            emblemIcon: "arrow.triangle.2.circlepath",
            steps: ["1. Uygulama Listesi", "2. Appcast Taraması", "3. Sürüm Doğrulama"],
            currentStepIndex: 1,
            progressFraction: 0.65,
            currentItemName: "Applications taranıyor..."
        )
    }
    
    // MARK: - 4. Sonuçlar Sahnesi
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Özet Banner
            HStack(spacing: 16) {
                if updates.isEmpty {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tüm Uygulamalarınız Güncel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Mac'inizde tespit edilen \(totalAppsCount) uygulamanın tamamı en son kararlı sürümdedir.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "0284C7").opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "38BDF8"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(updates.count) Uygulama Güncellemesi Mevcut")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Yazılımlarınızı en son özellikler ve kararlılık için güncel tutun.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Tümünü Güncelle Butonu (Tek Tıkla Sıralı Otomatik Güncelleme)
                    Button(action: {
                        Task {
                            await updaterEngine.updateAll(items: updates)
                            HapticManager.shared.triggerSuccess()
                        }
                        HapticManager.shared.triggerClick()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Tümünü Tek Tıkla Güncelle (\(updates.count))")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "0284C7"), Color(hex: "2563EB")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color(hex: "0284C7").opacity(0.4), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.04))
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Güncelleme Kartları Listesi
            ScrollView {
                LazyVStack(spacing: 10) {
                    if updates.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "app.badge.checkmark.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green.opacity(0.8))
                            Text("Bekleyen Güncelleme Yok")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("Mac'inizdeki tüm uygulamalar en yeni sürümde çalışıyor.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        ForEach(filteredUpdates) { item in
                            appUpdateRow(item: item)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }
    
    // MARK: - 5. Tekil Güncelleme Satırı
    private func appUpdateRow(item: AppUpdateItem) -> some View {
        HStack(spacing: 14) {
            // Uygulama Simgesi
            let appIcon = NSWorkspace.shared.icon(forFile: item.appPath)
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 44, height: 44)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.appName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Kaynak Etiketi
                    Text(item.source.rawValue)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.source == .sparkle ? Color.purple.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(item.source == .sparkle ? Color(hex: "C084FC") : Color(hex: "FDBA74"))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 6) {
                    Text("Mevcut: v\(item.currentVersion)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "38BDF8"))
                    
                    Text("Yeni: v\(item.latestVersion)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "38BDF8"))
                }
            }
            
            Spacer()
            
            // Değişiklik Notları Butonu
            if let rel = item.releaseNotesUrl, let url = URL(string: rel) {
                Button(action: { NSWorkspace.shared.open(url) }) {
                    Text("Yenilikler")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.85))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            // Tek Tıkla Otomatik Güncelleme Buton Grubu
            updateActionView(for: item)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func updateActionView(for item: AppUpdateItem) -> some View {
        let status = updaterEngine.updatingStatuses[item.id] ?? .idle
        
        switch status {
        case .idle:
            Button(action: {
                Task {
                    await updaterEngine.performOneClickUpdate(for: item)
                    HapticManager.shared.triggerSuccess()
                }
                HapticManager.shared.triggerClick()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Tek Tıkla Güncelle")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "0284C7"))
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
                Text("%\(Int(progress * 100)) İndiriliyor")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "38BDF8"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "0284C7").opacity(0.3))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "38BDF8").opacity(0.4), lineWidth: 1)
            )
            
        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
                Text("Kuruluyor...")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "FDE047"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "CA8A04").opacity(0.25))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "FDE047").opacity(0.4), lineWidth: 1)
            )
            
        case .completed:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
                Text("Güncellendi")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.18))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
            
        case .failed(let errorMsg):
            Button(action: {
                updaterEngine.openUpdate(for: item)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "safari")
                        .font(.system(size: 10, weight: .bold))
                    Text("Manuel İndir")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Otomatik kurulum hatası: \(errorMsg). Manuel indirmek için tıklayın.")
        }
    }
    
    private func startScan() {
        isScanning = true
        Task {
            let (foundUpdates, total) = await AppUpdaterEngine.shared.scanAvailableUpdates()
            await MainActor.run {
                self.updates = foundUpdates
                self.totalAppsCount = total
                self.isScanning = false
                self.hasScanned = true
                self.engine.availableUpdates = foundUpdates
                self.engine.totalInstalledAppsCount = total
            }
        }
    }
}
