import SwiftUI
import AppKit
import IhyaCore

public enum AppTab: String, CaseIterable, Identifiable {
    case smartClean = "Akıllı Arınma"
    case spaceLens = "Hacim Röntgeni"
    case uninstaller = "Derin Kaldırıcı"
    case appUpdater = "Yazılım Güncelleyici"
    case duplicateFinder = "Çift Dosya Avcısı"
    case browserPrivacy = "Tarayıcı & Web"
    case appLipo = "Mimari İnceltici"
    case developerVault = "Geliştirici Kasası"
    case ghostDaemons = "Hayalet Servisler"
    case systemOptimize = "Sistem & Bellek"
    case settings = "Ayarlar & Lisans"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .smartClean: return "sparkles"
        case .spaceLens: return "circle.hexagongrid.fill"
        case .uninstaller: return "xmark.bin.fill"
        case .appUpdater: return "arrow.triangle.2.circlepath.circle.fill"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .browserPrivacy: return "globe"
        case .developerVault: return "hammer.fill"
        case .ghostDaemons: return "bolt.shield.fill"
        case .appLipo: return "scissors"
        case .systemOptimize: return "memorychip"
        case .settings: return "gearshape.fill"
        }
    }
    
    public var sectionName: String {
        switch self {
        case .smartClean: return "GENEL"
        case .spaceLens, .uninstaller, .appUpdater, .duplicateFinder, .browserPrivacy, .appLipo: return "UYGULAMA & ALAN"
        case .systemOptimize, .developerVault, .ghostDaemons: return "PERFORMANS & KORUMA"
        case .settings: return "SİSTEM"
        }
    }
}

public struct MainView: View {
    @StateObject private var engine = CleanerEngine.shared
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var selectedTab: AppTab = .smartClean
    @State private var selectedCategoryForXRay: CategorySummary? = nil
    @State private var licenseInputKey: String = ""
    @State private var licenseStatusMessage: String = ""
    @State private var hasStartedSmartScan: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Dinamik Tematik Akışkan Zemin (CleanMyMac-tarzı Tab'a Göre Değişen Aurora)
            backgroundAtmosphere
                .ignoresSafeArea()
            
            // 2. Ana Uygulama Gövdesi (Sol Geniş Lüks Sidebar + Sağ Sahne)
            HStack(spacing: 0) {
                // Sol Geniş Cam Kenar Çubuğu (~210px)
                sidebarView
                    .frame(width: 216)
                
                // Sağ Ana Sahne Alanı
                ZStack(alignment: .trailing) {
                    VStack(spacing: 0) {
                        // Üst İnce Durum Çubuğu
                        topHeaderBar
                        
                        // İçerik Alanı
                        ZStack {
                            switch selectedTab {
                            case .smartClean:
                                smartCleanStage
                            case .spaceLens:
                                SpaceLensView()
                            case .uninstaller:
                                AppUninstallerView()
                            case .appUpdater:
                                AppUpdaterView()
                            case .duplicateFinder:
                                DuplicateFinderView()
                            case .browserPrivacy:
                                BrowserPrivacyView()
                            case .developerVault:
                                developerVaultStage
                            case .ghostDaemons:
                                ghostDaemonsStage
                            case .appLipo:
                                appLipoStage
                            case .systemOptimize:
                                SystemOptimizationView()
                            case .settings:
                                settingsStage
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // X-Ray Röntgen Çekmecesi (Sağdan Kayan Cam Katman)
                    if let cat = selectedCategoryForXRay {
                        XRayDrawerView(category: cat) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedCategoryForXRay = nil
                            }
                        }
                        .transition(.move(edge: .trailing))
                        .shadow(color: .black.opacity(0.5), radius: 28, x: -8, y: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 1. Dinamik Tematik Akışkan Zemin
    private var backgroundAtmosphere: some View {
        ZStack {
            // Temel Gradient
            LinearGradient(
                colors: tabGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Aurora Işık Halesi 1 (Sol Üst)
            GeometryReader { geo in
                Circle()
                    .fill(tabPrimaryAuroraColor.opacity(0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .blur(radius: 120)
                    .offset(x: -geo.size.width * 0.15, y: -geo.size.height * 0.25)
                
                // Aurora Işık Halesi 2 (Sağ Alt)
                Circle()
                    .fill(tabSecondaryAuroraColor.opacity(0.22))
                    .frame(width: geo.size.width * 0.6, height: geo.size.width * 0.6)
                    .blur(radius: 110)
                    .offset(x: geo.size.width * 0.45, y: geo.size.height * 0.35)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: selectedTab)
    }
    
    private var tabGradientColors: [Color] {
        switch selectedTab {
        case .smartClean:
            return [Color(hex: "1F0C3B"), Color(hex: "0D051B"), Color(hex: "07030F")]
        case .spaceLens:
            return [Color(hex: "041C24"), Color(hex: "020E12"), Color(hex: "010709")]
        case .uninstaller:
            return [Color(hex: "2D080A"), Color(hex: "120304"), Color(hex: "080102")]
        case .appUpdater:
            return [Color(hex: "031B38"), Color(hex: "020D1D"), Color(hex: "01060E")]
        case .developerVault:
            return [Color(hex: "2B1204"), Color(hex: "120602"), Color(hex: "080301")]
        case .ghostDaemons:
            return [Color(hex: "1D0E38"), Color(hex: "0C0519"), Color(hex: "06020E")]
        case .duplicateFinder:
            return [Color(hex: "061933"), Color(hex: "020C1A"), Color(hex: "01050D")]
        case .appLipo:
            return [Color(hex: "2B0715"), Color(hex: "100208"), Color(hex: "080104")]
        case .browserPrivacy:
            return [Color(hex: "041E28"), Color(hex: "020F15"), Color(hex: "01070A")]
        case .systemOptimize:
            return [Color(hex: "04221E"), Color(hex: "021210"), Color(hex: "010908")]
        case .settings:
            return [Color(hex: "111622"), Color(hex: "090C13"), Color(hex: "040609")]
        }
    }
    
    private var tabPrimaryAuroraColor: Color {
        switch selectedTab {
        case .smartClean: return Color(hex: "9333EA")
        case .spaceLens: return Color(hex: "06B6D4")
        case .uninstaller: return Color(hex: "EF4444")
        case .appUpdater: return Color(hex: "38BDF8")
        case .developerVault: return Color(hex: "F59E0B")
        case .ghostDaemons: return Color(hex: "8B5CF6")
        case .duplicateFinder: return Color(hex: "0284C7")
        case .appLipo: return Color(hex: "F43F5E")
        case .browserPrivacy: return Color(hex: "0EA5E9")
        case .systemOptimize: return Color(hex: "14B8A6")
        case .settings: return Color(hex: "64748B")
        }
    }
    
    private var tabSecondaryAuroraColor: Color {
        switch selectedTab {
        case .smartClean: return Color(hex: "EC4899")
        case .spaceLens: return Color(hex: "0891B2")
        case .uninstaller: return Color(hex: "B91C1C")
        case .appUpdater: return Color(hex: "2563EB")
        case .developerVault: return Color(hex: "D97706")
        case .ghostDaemons: return Color(hex: "6366F1")
        case .duplicateFinder: return Color(hex: "2563EB")
        case .appLipo: return Color(hex: "BE123C")
        case .browserPrivacy: return Color(hex: "06B6D4")
        case .systemOptimize: return Color(hex: "0D9488")
        case .settings: return Color(hex: "475569")
        }
    }
    
    // MARK: - 2. Sol Geniş Cam Kenar Çubuğu (Sidebar)
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo & Marka Başlığı
            HStack(spacing: 10) {
                if let path = Bundle.main.path(forResource: "icon_1024", ofType: "png"),
                   let img = NSImage(contentsOfFile: path) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                        .shadow(color: Color(hex: "06B6D4").opacity(0.4), radius: 6, x: 0, y: 2)
                } else if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                        .shadow(color: Color(hex: "06B6D4").opacity(0.4), radius: 6, x: 0, y: 2)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "38BDF8"), Color(hex: "7C3AED")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("İhyâ")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.2") (Native)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 22)
            
            // Gruplandırılmış Navigasyon Listesi
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarSection(title: "GENEL", tabs: [.smartClean])
                    sidebarSection(title: "UYGULAMA & ALAN", tabs: [.spaceLens, .uninstaller, .appUpdater, .duplicateFinder, .browserPrivacy, .appLipo])
                    sidebarSection(title: "PERFORMANS & KORUMA", tabs: [.systemOptimize, .developerVault, .ghostDaemons])
                    sidebarSection(title: "SİSTEM", tabs: [.settings])
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            // Alt Donanım & Lisans Rozetleri
            VStack(alignment: .leading, spacing: 8) {
                // Donanım Özeti
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(HardwareInfo.summary)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                // VIP / Lisans Rozeti
                HStack {
                    if licenseManager.isProUnlocked {
                        HStack(spacing: 4) {
                            Text("PRO")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: "7C3AED"))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            
                            Text(licenseManager.hwidGrantTitle ?? "Ömür Boyu VIP")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    } else {
                        Button(action: { selectedTab = .settings }) {
                            HStack(spacing: 4) {
                                Text("FREE")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white.opacity(0.7))
                                    .cornerRadius(4)
                                
                                Text("Pro'ya Yükselt")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: "38BDF8"))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.22))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    private func sidebarSection(title: String, tabs: [AppTab]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
            
            ForEach(tabs) { tab in
                let key = tabShortcut(for: tab)
                Button(action: {
                    selectedTab = tab
                    selectedCategoryForXRay = nil
                    HapticManager.shared.triggerClick()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.55))
                            .frame(width: 18)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.7))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab ?
                        Color.white.opacity(0.12) :
                        Color.clear
                    )
                    .cornerRadius(8)
                    .overlay(
                        selectedTab == tab ?
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1) : nil
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(key, modifiers: .command)
            }
        }
    }
    
    private func tabShortcut(for tab: AppTab) -> KeyEquivalent {
        switch tab {
        case .smartClean: return "1"
        case .spaceLens: return "2"
        case .uninstaller: return "3"
        case .appUpdater: return "u"
        case .duplicateFinder: return "4"
        case .browserPrivacy: return "5"
        case .appLipo: return "6"
        case .developerVault: return "7"
        case .ghostDaemons: return "8"
        case .systemOptimize: return "9"
        case .settings: return ","
        }
    }
    
    // MARK: - Üst İnce Durum Çubuğu
    private var topHeaderBar: some View {
        HStack {
            Text(selectedTab.rawValue)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Disk Bilgi Rozeti
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(DiskInfo.current)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.12))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Smart Clean Stage (Idle Hero vs Bento Grid)
    @ViewBuilder
    private var smartCleanStage: some View {
        if !hasStartedSmartScan && !engine.isScanning && engine.totalReclaimableBytes == 0 {
            // Boşta / İlk Açılış Hero Sahnesi
            HeroStageView(
                title: "Akıllı Arınma",
                subtitle: "Macintosh sisteminizi tek dokunuşla derinlemesine arındırın, hafızayı boşaltın ve hızı ilk günkü tazeliğine kavuşturun.",
                emblemStyle: .emerald,
                emblemIcon: "sparkles",
                bullets: [
                    .init(
                        icon: "bolt.fill",
                        title: "Sistem Çöpleri ve Önbellekler",
                        description: "Kullanıcı, sistem ve uygulama önbelleklerini, çökme loglarını temizler."
                    ),
                    .init(
                        icon: "shield.fill",
                        title: "Gizli Servisler ve Pil Koruma",
                        description: "Sildiğiniz programlardan kalan ölü arka plan ajanlarını ve tehditleri tespit eder."
                    ),
                    .init(
                        icon: "arrow.triangle.2.circlepath",
                        title: "İkiz Dosyalar ve Geliştirici Artıkları",
                        description: "Çift indirmeleri, ölü Intel (x86_64) mimari kodlarını ve Xcode artıklarını arındırır."
                    )
                ],
                targetDiskInfo: DiskInfo.current,
                buttonTitle: "Sistemi Tara",
                buttonColorStyle: .primaryViolet,
                onAction: {
                    hasStartedSmartScan = true
                    startSmartCleanScan()
                }
            )
        } else {
            // Bento Grid Sahnesi + Yüzen Buton
            ZStack(alignment: .bottom) {
                smartCareBentoStage
                
                // Alt Merkez Yüzen Kristal Düğme
                FloatingActionButton(
                    title: floatingButtonTitle,
                    icon: floatingButtonIcon,
                    isPulsing: engine.isScanning,
                    colorStyle: floatingButtonColorStyle
                ) {
                    HapticManager.shared.triggerClick()
                    if engine.totalReclaimableBytes > 0 && !engine.isScanning {
                        Task {
                            _ = await engine.performClean()
                            SoundManager.shared.playCleanFinished()
                            HapticManager.shared.triggerSuccess()
                        }
                    } else if !engine.isScanning {
                        startSmartCleanScan()
                    }
                }
                .offset(y: -12)
            }
        }
    }
    
    private func startSmartCleanScan() {
        Task {
            await engine.runFullScan()
            SoundManager.shared.playSuccess()
            HapticManager.shared.triggerSuccess()
        }
    }
    
    // MARK: - Smart Care Lüks Bento Grid
    private var smartCareBentoStage: some View {
        VStack(spacing: 14) {
            // Anlık Taranan Dosya Yolu Canlı Rozeti (CleanMyMac Orb Paritesi)
            if engine.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Taranıyor:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text(engine.currentScanningPath.isEmpty ? engine.currentTaskName : engine.currentScanningPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "38BDF8"))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.4))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "06B6D4").opacity(0.4), lineWidth: 1)
                )
                .transition(.opacity)
            }
            
            // ÜST BENTO SIRASI (3 KART)
            HStack(spacing: 16) {
                // 1. Kart: Sistem Temizliği
                let sysCat = engine.categories.first(where: { $0.category == .systemJunk })
                let isSysActive = engine.currentPhase == .systemJunk
                let isSysDone = engine.currentPhase != .idle && engine.currentPhase != .systemJunk
                
                BentoCardView(
                    title: "Sistem Arınması",
                    subtitle: isSysActive ? "Çöpler Taranıyor..." : (sysCat?.totalSize ?? 0 > 0 ? sysCat!.formattedSize : "Taramaya Hazır"),
                    statusText: isSysActive ? "Taranıyor..." : (engine.hasCleaned ? "Arındırıldı" : (isSysDone ? "Açılabilir Alan" : "Önbellek & Günlükler")),
                    isCompleted: isSysDone && (sysCat?.totalSize ?? 0 > 0 || engine.currentPhase == .completed),
                    isCleaned: engine.hasCleaned,
                    isActive: isSysActive,
                    emblemStyle: .emerald,
                    emblemIcon: "sparkles",
                    itemsBreakdown: isSysActive ? [
                        (name: "Kullanıcı Önbellekleri", size: "Taranıyor..."),
                        (name: "Sistem Günlük Dosyaları", size: "Taranıyor..."),
                        (name: "Çökme & Tanı Raporları", size: "Taranıyor..."),
                        (name: "Unutulmuş Disk Kalıpları", size: "Taranıyor...")
                    ] : nil
                ) {
                    if let c = sysCat {
                        withAnimation(.spring()) { selectedCategoryForXRay = c }
                        HapticManager.shared.triggerClick()
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 2. Kart: Tarayıcı & Web Kasası
                let browserCat = engine.categories.first(where: { $0.category == .browserCaches })
                let isBrowserActive = engine.currentPhase == .browserCaches
                let isBrowserDone = engine.currentPhase != .idle && engine.currentPhase != .systemJunk && engine.currentPhase != .browserCaches
                
                BentoCardView(
                    title: "Tarayıcı & Web",
                    subtitle: isBrowserActive ? "Web Taranıyor..." : (browserCat?.totalSize ?? 0 > 0 ? browserCat!.formattedSize : "Taramaya Hazır"),
                    statusText: isBrowserActive ? "Taranıyor..." : (engine.hasCleaned ? "Arındırıldı" : (isBrowserDone ? "Açılabilir Alan" : (engine.isScanning ? "Sırada bekliyor..." : "Safari, Chrome, Brave"))),
                    isCompleted: isBrowserDone && (browserCat?.totalSize ?? 0 > 0 || engine.currentPhase == .completed),
                    isCleaned: engine.hasCleaned,
                    isActive: isBrowserActive,
                    emblemStyle: .cyan,
                    emblemIcon: "globe",
                    itemsBreakdown: isBrowserActive ? [
                        (name: "Safari WebKit Önbelleği", size: "Taranıyor..."),
                        (name: "Chrome V8 Kod Önbelleği", size: "Taranıyor..."),
                        (name: "Brave & Arc Web Verileri", size: "Taranıyor..."),
                        (name: "Geçici Web Medyaları", size: "Taranıyor...")
                    ] : nil
                ) {
                    if let c = browserCat {
                        withAnimation(.spring()) { selectedCategoryForXRay = c }
                        HapticManager.shared.triggerClick()
                    } else {
                        selectedTab = .browserPrivacy
                        HapticManager.shared.triggerClick()
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 3. Kart: Uygulama & Güncelleme
                let isUpActive = engine.currentPhase == .appLipo && engine.isScanning
                let isUpDone = engine.currentPhase == .completed
                let updatesCount = engine.availableUpdates.count
                let totalApps = engine.totalInstalledAppsCount
                
                BentoCardView(
                    title: "Uygulama & Güncelleme",
                    subtitle: isUpActive ? "Sürümler Taranıyor..." : (updatesCount > 0 ? "\(updatesCount) Kritik Güncelleme" : "\(totalApps > 0 ? "\(totalApps)" : "73") Uygulama"),
                    statusText: isUpActive ? "Taranıyor..." : (updatesCount > 0 ? "Güncellemeye Hazır" : (isUpDone ? "Tüm Uygulamalar Güncel" : (engine.isScanning ? "Sırada bekliyor..." : "Sparkle & Paket Takibi"))),
                    isCompleted: isUpDone,
                    isCleaned: engine.hasCleaned,
                    isActive: isUpActive,
                    emblemStyle: .sapphire,
                    emblemIcon: "arrow.triangle.2.circlepath.circle.fill",
                    itemsBreakdown: isUpActive ? [
                        (name: "Yüklü Uygulama Sürümleri", size: "Taranıyor..."),
                        (name: "Sparkle Appcast Beslemeleri", size: "Taranıyor..."),
                        (name: "Homebrew Cask Paketleri", size: "Taranıyor..."),
                        (name: "Kaldırılmış Artık Kayıtlar", size: "Taranıyor...")
                    ] : nil
                ) {
                    selectedTab = .appUpdater
                    HapticManager.shared.triggerClick()
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            // ALT BENTO SIRASI (3 KART)
            HStack(spacing: 16) {
                // 4. Kart: Hayalet Servisler
                let isGhostActive = engine.currentPhase == .ghostDaemons
                let isGhostDone = engine.currentPhase == .duplicates || engine.currentPhase == .appLipo || engine.currentPhase == .completed
                
                BentoCardView(
                    title: "Hayalet Servisler",
                    subtitle: isGhostActive ? "Ajanlar İnceleniyor..." : "\(engine.ghostDaemons.count) Tehdit",
                    statusText: isGhostActive ? "Taranıyor..." : (engine.hasCleaned ? "Temizlendi" : (isGhostDone ? "Temizlenmeye Hazır" : (engine.isScanning ? "Sırada bekliyor..." : "Pil Koruması Tam"))),
                    isCompleted: isGhostDone,
                    isCleaned: engine.hasCleaned,
                    isActive: isGhostActive,
                    emblemStyle: .violet,
                    emblemIcon: "bolt.shield.fill"
                ) {
                    selectedTab = .ghostDaemons
                    HapticManager.shared.triggerClick()
                }
                .frame(maxWidth: .infinity)

                // 5. Kart: Çift Dosya Avcısı
                let isDupActive = engine.currentPhase == .duplicates
                let isDupDone = engine.currentPhase == .appLipo || engine.currentPhase == .completed
                let dupTotalReclaim = engine.duplicates.reduce(0) { $0 + $1.reclaimableSize }
                
                BentoCardView(
                    title: "Çift Dosya Avcısı",
                    subtitle: isDupActive ? "İkizler Aranıyor..." : "\(engine.duplicates.count) İkiz Grup",
                    statusText: isDupActive ? "Taranıyor..." : (engine.hasCleaned ? "Temizlendi" : (isDupDone ? "\(ByteCountFormatter.string(fromByteCount: dupTotalReclaim, countStyle: .file)) Kopya" : (engine.isScanning ? "Sırada bekliyor..." : "İkiz İndirmeler & Belgeler"))),
                    isCompleted: isDupDone && !engine.duplicates.isEmpty,
                    isCleaned: engine.hasCleaned,
                    isActive: isDupActive,
                    emblemStyle: .sapphire,
                    emblemIcon: "doc.on.doc.fill",
                    itemsBreakdown: isDupActive ? [
                        (name: "İndirilen Dosyalar", size: "Taranıyor..."),
                        (name: "Kopya Görseller", size: "Taranıyor..."),
                        (name: "Tekrarlanan Belgeler", size: "Taranıyor...")
                    ] : nil
                ) {
                    selectedTab = .duplicateFinder
                    HapticManager.shared.triggerClick()
                }
                .frame(maxWidth: .infinity)
                
                // 6. Kart: Geliştirici Kasası
                let devCat = engine.categories.first(where: { $0.category == .developerVault })
                let isDevActive = engine.currentPhase == .developerVault
                let isDevDone = engine.currentPhase == .completed
                
                BentoCardView(
                    title: "Geliştirici Kasası",
                    subtitle: isDevActive ? "Önbellekler Taranıyor..." : (devCat?.totalSize ?? 0 > 0 ? devCat!.formattedSize : "Taramaya Hazır"),
                    statusText: isDevActive ? "Taranıyor..." : (engine.hasCleaned ? "Arındırıldı" : (isDevDone ? "Açılabilir Alan" : (engine.isScanning ? "Sırada bekliyor..." : "Xcode, Docker, Node"))),
                    isCompleted: isDevDone && (devCat?.totalSize ?? 0 > 0 || engine.currentPhase == .completed),
                    isCleaned: engine.hasCleaned,
                    isActive: isDevActive,
                    emblemStyle: .amber,
                    emblemIcon: "hammer.fill",
                    itemsBreakdown: isDevActive ? [
                        (name: "Xcode DerivedData", size: "Taranıyor..."),
                        (name: "Docker İmajları", size: "Taranıyor..."),
                        (name: "Node Paket Önbelleği", size: "Taranıyor..."),
                        (name: "Homebrew Şişeleri", size: "Taranıyor...")
                    ] : nil
                ) {
                    if let c = devCat {
                        withAnimation(.spring()) { selectedCategoryForXRay = c }
                        HapticManager.shared.triggerClick()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            // Sistem İçerik Dağılımı ve Envanter Özeti (Görseller, Videolar, Müzik, Belgeler, Çift Kayıtlar)
            if !engine.isScanning && (engine.mediaInventory.imagesCount > 0 || engine.mediaInventory.videosCount > 0 || !engine.duplicates.isEmpty) {
                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.fill")
                            .foregroundColor(Color(hex: "38BDF8"))
                            .font(.system(size: 11))
                        Text("\(engine.mediaInventory.imagesCount) Görsel")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "film.fill")
                            .foregroundColor(Color(hex: "A855F7"))
                            .font(.system(size: 11))
                        Text("\(engine.mediaInventory.videosCount) Video")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "music.note")
                            .foregroundColor(Color(hex: "EC4899"))
                            .font(.system(size: 11))
                        Text("\(engine.mediaInventory.audioCount) Ses")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "doc.fill")
                            .foregroundColor(Color(hex: "F59E0B"))
                            .font(.system(size: 11))
                        Text("\(engine.mediaInventory.documentsCount) Belge")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(Color(hex: "10B981"))
                            .font(.system(size: 11))
                        Text("\(engine.duplicates.count) İkiz Grup (\(engine.mediaInventory.formattedDuplicatesSize))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "34D399"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            
            Spacer().frame(height: 54)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 20)
    }
    
    private var floatingButtonTitle: String {
        if engine.isScanning { return "Durdur" }
        if engine.totalReclaimableBytes > 0 { return "Arındır (\(engine.formattedTotalReclaimable))" }
        return "Sistemi Tara"
    }
    
    private var floatingButtonIcon: String {
        if engine.isScanning { return "stop.fill" }
        if engine.totalReclaimableBytes > 0 { return "sparkles" }
        return "radar"
    }
    
    private var floatingButtonColorStyle: FloatingActionButton.ColorStyle {
        if engine.isScanning { return .dangerStop }
        if engine.totalReclaimableBytes > 0 { return .successEmerald }
        return .primaryViolet
    }
    
    // MARK: - Reusable Stage Scanning Indicator
    private func stageScanningView(title: String, subtitle: String, tintColor: Color) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(tintColor)
            
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }

    // MARK: - Developer Vault Stage
    private var developerVaultStage: some View {
        let devCategory = engine.categories.first(where: { $0.category == .developerVault })
        let items = devCategory?.items ?? []
        
        return Group {
            if engine.isScanning {
                stageScanningView(
                    title: "Geliştirici Kasası Taranıyor...",
                    subtitle: "Xcode DerivedData, Docker ve paket önbellekleri taranıyor...",
                    tintColor: Color(hex: "F59E0B")
                )
            } else if items.isEmpty {
                if hasStartedSmartScan {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52))
                            .foregroundColor(Color(hex: "10B981"))
                        Text("Harika! Geliştirici dizinleriniz tertemiz.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Xcode DerivedData ve paket önbelleklerinde şişkinlik bulunmuyor.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HeroStageView(
                        title: "Geliştirici & Üretici Kasası",
                        subtitle: "Xcode DerivedData, ölü simülatörler, Docker imajları ve devasa Node paket önbelleklerini temizleyerek diskinizi hafifletin.",
                        emblemStyle: .amber,
                        emblemIcon: "hammer.fill",
                        bullets: [
                            .init(
                                icon: "hammer.fill",
                                title: "Xcode Derleme Artıkları",
                                description: "Eski Xcode DerivedData, derleme önbellekleri ve arşivleri güvenle arındırır."
                            ),
                            .init(
                                icon: "shippingbox.fill",
                                title: "Paket & Paket Yöneticisi Önbellekleri",
                                description: "Homebrew indirilen şişeleri, npm, yarn, pnpm ve Gradle önbellekleri."
                            ),
                            .init(
                                icon: "cpu.fill",
                                title: "Ölü Cihaz & Simülatörler",
                                description: "Artık kullanılmayan iOS simülatör cihazlarını ve tanı günlüklerini temizler."
                            )
                        ],
                        targetDiskInfo: "Geliştirici Dizinleri (~/Library/Developer, ~/.npm, ~/.brew)",
                        buttonTitle: "Geliştirici Kasasını Tara",
                        buttonColorStyle: .goldenAmber,
                        onAction: {
                            hasStartedSmartScan = true
                            startSmartCleanScan()
                        }
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Geliştirici Kasası Sonuçları")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(items.count) Adet Geliştirici Artığı Bulundu")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        
                        Button("Geliştirici Artıklarını Temizle") {
                            Task {
                                _ = await engine.performCleanCategory(.developerVault)
                                SoundManager.shared.playCleanFinished()
                                HapticManager.shared.triggerSuccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    
                    List(items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(Color(hex: "F59E0B"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text(item.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Ghost Daemons Stage
    private var ghostDaemonsStage: some View {
        Group {
            if engine.isScanning {
                stageScanningView(
                    title: "Hayalet Servisler Taranıyor...",
                    subtitle: "LaunchAgents ve LaunchDaemons ölü plist'leri inceleniyor...",
                    tintColor: Color(hex: "8B5CF6")
                )
            } else if engine.ghostDaemons.isEmpty {
                if hasStartedSmartScan {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 52))
                            .foregroundColor(Color(hex: "10B981"))
                        Text("Harika! Sisteminizde hayalet veya ölü servis bulunmuyor.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Tüm arka plan servisleri geçerli ve sağlıklı.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HeroStageView(
                        title: "Hayalet Servis Avcısı",
                        subtitle: "Sildiğiniz programlardan geriye kalan ve arka planda pili tüketen ölü servisleri ve yetim ajanları ortadan kaldırın.",
                        emblemStyle: .violet,
                        emblemIcon: "bolt.shield.fill",
                        bullets: [
                            .init(
                                icon: "battery.100.bolt",
                                title: "Pil ve Bellek Tasarrufu",
                                description: "Arka planda döngüye giren ve işlemciyi yoran ölü daemons servislerini durdurur."
                            ),
                            .init(
                                icon: "shield.checkerboard",
                                title: "Yetim Launchd Plist Denetimi",
                                description: "Hedef dosyası silinmiş fakat sistemi yok yere tetikleyen ajanları yakalar."
                            ),
                            .init(
                                icon: "trash.slash.fill",
                                title: "Tek Dokunuşla Yok Etme",
                                description: "Sistem stabilitesini bozmadan ölü tanımları güvenle diskten kaldırır."
                            )
                        ],
                        targetDiskInfo: "LaunchAgents & LaunchDaemons",
                        buttonTitle: "Hayalet Servisleri Tara",
                        buttonColorStyle: .royalPurple,
                        onAction: {
                            hasStartedSmartScan = true
                            startSmartCleanScan()
                        }
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tespit Edilen Hayalet Servisler")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(engine.ghostDaemons.count) Ölü Servis Bulundu")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        
                        Button("Tümünü Yok Et") {
                            engine.removeAllGhostDaemons()
                            SoundManager.shared.playCleanFinished()
                            HapticManager.shared.triggerSuccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "EF4444"))
                        .controlSize(.small)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    
                    List(engine.ghostDaemons) { ghost in
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "FBBF24"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ghost.label)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Hedef dosya silinmiş: \(ghost.missingBinaryPath)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(hex: "FB7185"))
                            }
                            Spacer()
                            Button("Servisi Yok Et") {
                                engine.removeGhostDaemon(ghost: ghost)
                                SoundManager.shared.playCardComplete()
                                HapticManager.shared.triggerSuccess()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - App Lipo Stage
    private var appLipoStage: some View {
        Group {
            if engine.isScanning {
                stageScanningView(
                    title: "Evrensel İkililer Taranıyor...",
                    subtitle: "Mach-O ikili başlıkları ve x86_64 dilimleri inceleniyor...",
                    tintColor: Color(hex: "F43F5E")
                )
            } else if engine.lipoCandidates.isEmpty {
                if hasStartedSmartScan {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "cpu")
                            .font(.system(size: 52))
                            .foregroundColor(Color(hex: "38BDF8"))
                        Text("Sisteminizdeki tüm uygulamalar zaten saf Apple Silicon veya optimize.")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HeroStageView(
                        title: "Mimari İnceltici (App Lipo)",
                        subtitle: "Apple Silicon Mac'inizde gereksiz yer kaplayan eski Intel (x86_64) mimari kodlarını güvenle budayın.",
                        emblemStyle: .rose,
                        emblemIcon: "scissors",
                        bullets: [
                            .init(
                                icon: "cpu.fill",
                                title: "Apple Silicon Saflığı",
                                description: "M-Serisi Mac'inizde asla çalıştırılmayacak Intel kod dilimini kaldırır."
                            ),
                            .init(
                                icon: "bolt.shield.fill",
                                title: "Sıfır Hız Kaybı",
                                description: "Yerel ARM64 hızı %100 korunur, hiçbir performans ödünü verilmez."
                            ),
                            .init(
                                icon: "internaldrive",
                                title: "Gigabaytlarca Alan Açımı",
                                description: "Evrensel uygulamaların boyutunu ortalama %30-%50 oranında küçültür."
                            )
                        ],
                        targetDiskInfo: "/Applications Dizinindeki Evrensel İkililer",
                        buttonTitle: "Uygulamaları İncele",
                        buttonColorStyle: .sunsetRose,
                        onAction: {
                            hasStartedSmartScan = true
                            startSmartCleanScan()
                        }
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Budanabilecek Evrensel Uygulamalar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            let totalLipo = engine.lipoCandidates.reduce(0) { $0 + $1.reclaimableSize }
                            Text("+\(ByteCountFormatter.string(fromByteCount: totalLipo, countStyle: .file)) Alan Açılabilir")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "34D399"))
                        }
                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    
                    // Apple Gatekeeper Güvenlik Kalkanı Bilgilendirmesi
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "38BDF8"))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Gatekeeper & Kod İmzası Bütünlüğü")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Text("macOS güvenlik mimarisi gereği, geliştirici sertifikasıyla imzalanmış 3. parti uygulamaların ikili dilimlerini silmek kod imzasını bozar. İhyâ, sistem kararlılığını riske atmamak adına güvenli mimari röntgeni sunar.")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.65))
                                .lineSpacing(2)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    
                    List(engine.lipoCandidates) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "app.dashed")
                                .foregroundColor(Color(hex: "38BDF8"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.appName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text(item.appPath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("+\(item.formattedReclaimable)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "34D399"))
                                Text("Kazanılabilir")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Stage
    private var settingsStage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Ayarlar ve Lisans Yönetimi")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 24)
                
                // VIP Lisans Kartı
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("İhyâ Pro Lisansı")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(licenseManager.licenseTier.rawValue)
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(licenseManager.isProUnlocked ? Color(hex: "7C3AED") : Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    Text("Ömür boyu VIP lisansı cihazınıza donanımsal HMAC-SHA256 parmak izi ile kilitlenir. İnternetsiz (çevrimdışı) çalışır.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.65))
                    
                    HStack(spacing: 10) {
                        TextField("IHYA-PRO-XXXXXXXXXX-YYYYYYYY", text: $licenseInputKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        
                        Button("Etkinleştir") {
                            Task {
                                let result = await licenseManager.activate(key: licenseInputKey)
                                licenseStatusMessage = result.message
                                SoundManager.shared.playSuccess()
                                HapticManager.shared.triggerSuccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if !licenseStatusMessage.isEmpty {
                        Text(licenseStatusMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "38BDF8"))
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                
                // Cihaz ve Mimari Bilgisi
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cihaz Güvenliği & Çevrimdışı Parmak İzi")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack {
                        Text("Donanım Kimliği (HWID):")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(HardwareFingerprint.machineId)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "38BDF8"))
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(HardwareFingerprint.machineId, forType: .string)
                            HapticManager.shared.triggerSuccess()
                            licenseStatusMessage = "Donanım Kimliği (HWID) panoya kopyalandı."
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("HWID Kopyala")
                    }
                    
                    if let grant = licenseManager.hwidGrantTitle {
                        HStack {
                            Text("Özel Lisans Statüsü:")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(grant)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "34D399"))
                        }
                    }
                    
                    HStack {
                        Text("Sistem Mimarisi:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(HardwareInfo.summary)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Disk Durumu:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(DiskInfo.current)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Sistem & Donanım Yardımcıları
struct DiskInfo {
    static var current: String {
        let url = URL(fileURLWithPath: "/")
        if let values = try? url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            let name = values.volumeName ?? "Macintosh HD"
            let total = values.volumeTotalCapacity ?? 0
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            let totalStr = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
            let freeStr = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
            return "\(name) · \(totalStr) (\(freeStr) Boş)"
        }
        return "Macintosh HD · APFS"
    }
}

struct HardwareInfo {
    static var summary: String {
        #if arch(arm64)
        let arch = "Apple Silicon"
        #else
        let arch = "Intel x86_64"
        #endif
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(arch) · macOS \(os.majorVersion).\(os.minorVersion)"
    }
}
