import SwiftUI
import AppKit
import IhyaCore

public struct AppUpdaterView: View {
    @ObservedObject private var engine = CleanerEngine.shared
    @ObservedObject private var updaterEngine = AppUpdaterEngine.shared
    @State private var updates: [AppUpdateItem] = []
    @State private var installedApps: [InstalledAppInfo] = []
    @State private var totalAppsCount: Int = 0
    @State private var isScanning: Bool = false
    @State private var hasScanned: Bool = false
    @State private var searchQuery: String = ""
    @State private var selectedTab: Int = 0 // 0: Bekleyen Güncellemeler, 1: Tüm Yüklü Yazılımlar
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
    
    private var filteredInstalledApps: [InstalledAppInfo] {
        if searchQuery.isEmpty { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchQuery) ||
            $0.version.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Üst Kontrol ve Başlık Barı
            headerBar
            
            // 2. macOS Uygulama Yönetimi (App Management) İzni Uyarısı
            if updaterEngine.needsAppManagementPermission {
                appManagementPermissionBanner
            }
            
            // 3. Sekmeler Barı (Segmented Selector)
            if hasScanned {
                tabSelectorBar
            }
            
            Divider()
                .background(Color.white.opacity(0.10))
            
            // 4. Ana Sahne İçeriği
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
            syncStateFromEngine()
        }
    }
    
    // MARK: - Durum Senkronizasyonu
    private func syncStateFromEngine() {
        if !engine.availableUpdates.isEmpty || !engine.installedApps.isEmpty || engine.currentPhase == .completed {
            self.updates = engine.availableUpdates
            self.installedApps = engine.installedApps
            self.totalAppsCount = max(engine.totalInstalledAppsCount, engine.installedApps.count)
            self.hasScanned = true
        } else if !hasScanned {
            startScan()
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
                        Text(updates.isEmpty ? "Tüm Yazılımlar Güncel" : "\(updates.count) Güncelleme Mevcut")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(updates.isEmpty ? Color.green.opacity(0.2) : Color.blue.opacity(0.25))
                            .foregroundColor(updates.isEmpty ? Color(hex: "34D399") : Color(hex: "38BDF8"))
                            .cornerRadius(10)
                    }
                }
                
                Text(hasScanned ? "Mac'inizde \(max(totalAppsCount, installedApps.count)) uygulama denetlendi. Resmi Sparkle ve Homebrew paketleri taranıyor." : "Uygulamalarınızın Sparkle ve paket güncellemelerini tek merkezden yönetin.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Arama Kutusu
            if hasScanned {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField(selectedTab == 0 ? "Güncellemelerde ara..." : "Yüklü yazılımlarda ara...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 160)
                    
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
    
    // MARK: - 2. macOS Uygulama Yönetimi İzni Uyarısı
    private var appManagementPermissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "FBBF24"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("macOS Uygulama Değiştirme / Yönetim İzni Gerekiyor")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("macOS Sequoia / Sonoma, İhyâ'nın diğer uygulamaları otomatik güncellemesi için 'Uygulama Yönetimi' izni ister. Sistem Ayarları'ndan İhyâ'ya izin verip tek tıkla güncellemeye devam edebilirsiniz.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    updaterEngine.openAppManagementSettings()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Sistem Ayarlarını Aç")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "F59E0B"))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    updaterEngine.needsAppManagementPermission = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "B45309").opacity(0.25))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "F59E0B").opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
    
    // MARK: - 3. Sekmeler Barı
    private var tabSelectorBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 0 }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Bekleyen Güncellemeler")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("\(updates.count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(updates.isEmpty ? Color.white.opacity(0.1) : Color(hex: "0284C7"))
                        .foregroundColor(updates.isEmpty ? .white.opacity(0.6) : .white)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTab == 0 ? Color.white.opacity(0.12) : Color.clear)
                .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(selectedTab == 0 ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 1 }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tüm Yüklü Yazılımlar")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("\(max(totalAppsCount, installedApps.count))")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white.opacity(0.7))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedTab == 1 ? Color.white.opacity(0.12) : Color.clear)
                .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(selectedTab == 1 ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }
    
    // MARK: - 4. Boşta / Hero Durumu
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
                    description: "Geliştirici araçlarının ve paket yöneticilerinin güncel sürümlerini tespit eder."
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
    
    // MARK: - 5. Taranıyor Durumu
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
    
    // MARK: - 6. Sonuçlar Sahnesi
    private var resultsView: some View {
        VStack(spacing: 0) {
            if selectedTab == 0 {
                updatesTabContent
            } else {
                allAppsTabContent
            }
        }
    }
    
    // MARK: - 7. Bekleyen Güncellemeler Sekmesi İçeriği
    private var updatesTabContent: some View {
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
                        Text("Mac'inizde denetlenen \(max(totalAppsCount, installedApps.count)) uygulamanın tamamı en son kararlı sürümdedir.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 1 }
                    }) {
                        HStack(spacing: 5) {
                            Text("Yüklü Yazılımları Gör (\(max(totalAppsCount, installedApps.count)))")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
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
                        Text("Yazılımlarınızı en yeni özellikler ve güvenlik yamaları için güncel tutun.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Tümünü Güncelle Butonu
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
            .background(Color.white.opacity(0.03))
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Güncelleme Kartları Listesi
            ScrollView {
                LazyVStack(spacing: 10) {
                    if updates.isEmpty {
                        VStack(spacing: 14) {
                            Spacer()
                            Image(systemName: "app.badge.checkmark.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green.opacity(0.85))
                            
                            Text("Bekleyen Güncelleme Yok")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Mac'inizdeki tüm uygulamalar en yeni sürümde çalışıyor. Yeni güncellemeler yayınlandığında İhyâ sizi bilgilendirir.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 1 }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "laptopcomputer")
                                        .font(.system(size: 12))
                                    Text("Tüm Yüklü Yazılımları Listele (\(max(totalAppsCount, installedApps.count)))")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                            
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
    
    // MARK: - 8. Tüm Yüklü Yazılımlar Sekmesi İçeriği
    private var allAppsTabContent: some View {
        VStack(spacing: 0) {
            // Bilgi Başlığı
            HStack {
                Text("\(filteredInstalledApps.count) Adet Yüklü Yazılım Taranmış ve Doğrulanmıştır")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("Resmi Sürüm Doğrulandı ✓")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "34D399"))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.02))
            
            Divider()
                .background(Color.white.opacity(0.06))
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredInstalledApps) { app in
                        installedAppRow(app: app)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
        }
    }
    
    // MARK: - 9. Tekil Yüklü Uygulama Satırı
    private func installedAppRow(app: InstalledAppInfo) -> some View {
        HStack(spacing: 12) {
            let appIcon = NSWorkspace.shared.icon(forFile: app.appPath)
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 36, height: 36)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    if app.hasSparkle {
                        Text("Sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(Color(hex: "C084FC"))
                            .cornerRadius(4)
                    }
                }
                
                Text(app.bundleId.isEmpty ? app.appPath : app.bundleId)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("v\(app.version)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.05))
                .cornerRadius(5)
            
            if app.updateAvailable {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 0 }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .bold))
                        Text("Güncelleme Var")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color(hex: "0284C7").opacity(0.25))
                    .foregroundColor(Color(hex: "38BDF8"))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "0284C7").opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .heavy))
                    Text("Güncel")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .foregroundColor(Color(hex: "34D399"))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 10. Tekil Güncelleme Satırı
    private func appUpdateRow(item: AppUpdateItem) -> some View {
        HStack(spacing: 14) {
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
    
    // MARK: - 11. Güncelleme Aksiyon Butonları
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
            HStack(spacing: 6) {
                // Eğer izin engeli ise "İzin Ver" butonu
                Button(action: {
                    updaterEngine.openAppManagementSettings()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10, weight: .bold))
                        Text("İzin Ver")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(hex: "F59E0B").opacity(0.2))
                    .foregroundColor(Color(hex: "FBBF24"))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "F59E0B").opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("macOS Uygulama Yönetimi iznini açmak için tıklayın.")
                
                Button(action: {
                    updaterEngine.openUpdate(for: item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                            .font(.system(size: 10, weight: .bold))
                        Text("Manuel İndir")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
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
                .help("Hata: \(errorMsg). Doğrudan indirme sayfasına gitmek için tıklayın.")
            }
        }
    }
    
    // MARK: - 12. Tarama Başlatma
    private func startScan() {
        isScanning = true
        Task {
            let (foundUpdates, total, allApps) = await AppUpdaterEngine.shared.scanAvailableUpdates()
            await MainActor.run {
                self.updates = foundUpdates
                self.installedApps = allApps
                self.totalAppsCount = total
                self.isScanning = false
                self.hasScanned = true
                self.engine.availableUpdates = foundUpdates
                self.engine.installedApps = allApps
                self.engine.totalInstalledAppsCount = total
            }
        }
    }
}