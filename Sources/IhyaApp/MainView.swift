import SwiftUI
import AppKit
import IhyaCore

public enum AppTab: String, CaseIterable, Identifiable {
    case smartClean = "Akıllı Arınma"
    case spaceLens = "Hacim Röntgeni"
    case largeOldFiles = "Büyük & Eski Dosyalar"
    case uninstaller = "Derin Kaldırıcı"
    case appUpdater = "Yazılım Güncelleyici"
    case duplicateFinder = "Çift Dosya Avcısı"
    case browserPrivacy = "Tarayıcı & Web"
    case appLipo = "Mimari İnceltici"
    case developerVault = "Geliştirici Kasası"
    case ghostDaemons = "Hayalet Servisler"
    case systemOptimize = "Sistem & Bellek"
    case startupManager = "Başlangıç Yöneticisi"
    case settings = "Ayarlar & Lisans"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .smartClean: return "sparkles"
        case .spaceLens: return "circle.hexagongrid.fill"
        case .largeOldFiles: return "archivebox.fill"
        case .uninstaller: return "xmark.bin.fill"
        case .appUpdater: return "arrow.triangle.2.circlepath.circle.fill"
        case .duplicateFinder: return "doc.on.doc.fill"
        case .browserPrivacy: return "globe"
        case .developerVault: return "hammer.fill"
        case .ghostDaemons: return "bolt.shield.fill"
        case .appLipo: return "scissors"
        case .systemOptimize: return "memorychip"
        case .startupManager: return "play.square.stack.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    public var sectionName: String {
        switch self {
        case .smartClean: return "GENEL"
        case .spaceLens, .largeOldFiles, .uninstaller, .appUpdater, .duplicateFinder, .browserPrivacy, .appLipo: return "UYGULAMA & ALAN"
        case .systemOptimize, .startupManager, .developerVault, .ghostDaemons: return "PERFORMANS & KORUMA"
        case .settings: return "SİSTEM"
        }
    }
}

public struct MainView: View {
    @StateObject private var engine = CleanerEngine.shared
    @StateObject private var licenseManager = LicenseManager.shared
    @ObservedObject private var updateChecker = IhyaUpdateChecker.shared
    @ObservedObject private var dupEngine = DuplicateFinderEngine.shared
    @State private var selectedTab: AppTab = .smartClean
    @State private var selectedCategoryForXRay: CategorySummary? = nil
    @State private var licenseInputKey: String = ""
    @State private var licenseStatusMessage: String = ""
    @State private var hasStartedSmartScan: Bool = false
    @State private var showProPromoModal: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Dinamik Tematik Akışkan Zemin (CleanMyMac-tarzı Tab'a Göre Değişen Aurora)
            backgroundAtmosphere
                .ignoresSafeArea()
            
            // 2. Ana Uygulama Gövdesi (Sol Geniş Lüks Sidebar + Sağ Sahne)
            HStack(spacing: 0) {
                // Sol Geniş Cam Kenar Çubuğu (240px - Lüks ve Ferah Menü Hizalaması)
                sidebarView
                    .frame(width: 240)
                
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
                            case .largeOldFiles:
                                LargeOldFilesView()
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
                                SystemOptimizationView(onNavigateToStartupManager: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        selectedTab = .startupManager
                                    }
                                })
                            case .startupManager:
                                StartupManagerView()
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
            
            // 3. Pro Tanıtım & Satın Alma Modalı
            if showProPromoModal {
                proPromoModalOverlay
            }
        }
        .frame(minWidth: 960, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkFirstRunPromo()
            updateChecker.checkForUpdates(silent: true)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .smartClean {
                updateChecker.checkForUpdates(silent: true)
            }
        }
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
        case .largeOldFiles:
            return [Color(hex: "2B1804"), Color(hex: "140B02"), Color(hex: "080401")]
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
        case .startupManager:
            return [Color(hex: "1F143B"), Color(hex: "0D081D"), Color(hex: "06030F")]
        case .settings:
            return [Color(hex: "111622"), Color(hex: "090C13"), Color(hex: "040609")]
        }
    }
    
    private var tabPrimaryAuroraColor: Color {
        switch selectedTab {
        case .smartClean: return Color(hex: "9333EA")
        case .spaceLens: return Color(hex: "06B6D4")
        case .largeOldFiles: return Color(hex: "F59E0B")
        case .uninstaller: return Color(hex: "EF4444")
        case .appUpdater: return Color(hex: "38BDF8")
        case .developerVault: return Color(hex: "F59E0B")
        case .ghostDaemons: return Color(hex: "8B5CF6")
        case .duplicateFinder: return Color(hex: "0284C7")
        case .appLipo: return Color(hex: "F43F5E")
        case .browserPrivacy: return Color(hex: "0EA5E9")
        case .systemOptimize: return Color(hex: "14B8A6")
        case .startupManager: return Color(hex: "A855F7")
        case .settings: return Color(hex: "64748B")
        }
    }
    
    private var tabSecondaryAuroraColor: Color {
        switch selectedTab {
        case .smartClean: return Color(hex: "EC4899")
        case .spaceLens: return Color(hex: "0891B2")
        case .largeOldFiles: return Color(hex: "D97706")
        case .uninstaller: return Color(hex: "B91C1C")
        case .appUpdater: return Color(hex: "2563EB")
        case .developerVault: return Color(hex: "D97706")
        case .ghostDaemons: return Color(hex: "6366F1")
        case .duplicateFinder: return Color(hex: "2563EB")
        case .appLipo: return Color(hex: "BE123C")
        case .browserPrivacy: return Color(hex: "06B6D4")
        case .systemOptimize: return Color(hex: "0D9488")
        case .startupManager: return Color(hex: "6366F1")
        case .settings: return Color(hex: "475569")
        }
    }
    
    // MARK: - 2. Sol Geniş Cam Kenar Çubuğu (Sidebar)
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo & Marka Başlığı
            HStack(spacing: 8) {
                if let path = Bundle.main.path(forResource: "icon_1024", ofType: "png"),
                   let img = NSImage(contentsOfFile: path) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(7)
                        .shadow(color: Color(hex: "06B6D4").opacity(0.4), radius: 5, x: 0, y: 1)
                } else if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(7)
                        .shadow(color: Color(hex: "06B6D4").opacity(0.4), radius: 5, x: 0, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "38BDF8"), Color(hex: "7C3AED")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text("İhyâ")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            // Gruplandırılmış Navigasyon Listesi
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    sidebarSection(title: "GENEL", tabs: [.smartClean])
                    sidebarSection(title: "UYGULAMA & ALAN", tabs: [.spaceLens, .largeOldFiles, .uninstaller, .appUpdater, .duplicateFinder, .browserPrivacy, .appLipo])
                    sidebarSection(title: "PERFORMANS & KORUMA", tabs: [.systemOptimize, .startupManager, .developerVault, .ghostDaemons])
                    sidebarSection(title: "SİSTEM", tabs: [.settings])
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            // Alt Donanım & Lisans Rozetleri
            VStack(alignment: .leading, spacing: 8) {
                // Pro Satın Al Butonu / VIP Rozeti (Sidebar)
                if !licenseManager.isProUnlocked {
                    Button(action: {
                        showProPromoModal = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "FDE047"))
                            Text("Pro Satın Al")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "7C3AED"), Color(hex: "9333EA")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: Color(hex: "7C3AED").opacity(0.35), radius: 5, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                } else if licenseManager.hasPersonalLicense {
                    // TEK SATIR, SIFIR LOGO KALABALIĞI ÖMÜR BOYU VIP KARTI
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ömür Boyu VIP")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(HardwareInfo.summary)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "7C3AED").opacity(0.35), lineWidth: 1)
                    )
                } else {
                    // Trial veya Standart Pro
                    VStack(alignment: .leading, spacing: 3) {
                        Text(licenseManager.isTrialActive ? "Pro Deneme (\(licenseManager.trialDaysRemaining) gün)" : "İhyâ Pro")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(HardwareInfo.summary)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "2563EB").opacity(0.35), lineWidth: 1)
                    )
                }
                
                HStack {
                    Spacer()
                    
                    if updateChecker.updateAvailable {
                        Button(action: {
                            updateChecker.performDirectAutoUpdate()
                        }) {
                            HStack(spacing: 3) {
                                if updateChecker.isUpdating {
                                    ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                                    Text("...")
                                        .font(.system(size: 9, weight: .bold))
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("v\(updateChecker.latestVersion)")
                                        .font(.system(size: 9, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "38BDF8"), Color(hex: "2563EB")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Yeni sürümü indirip otomatik kurmak için tıklayın")
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
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
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 8)
                .padding(.bottom, 1)
            
            ForEach(tabs) { tab in
                let key = tabShortcut(for: tab)
                Button(action: {
                    selectedTab = tab
                    selectedCategoryForXRay = nil
                    HapticManager.shared.triggerClick()
                }) {
                    HStack(spacing: 9) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12.5, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.55))
                            .frame(width: 16, alignment: .center)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 11.5, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.75))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer(minLength: 4)
                        
                        if tab == .duplicateFinder && dupEngine.isScanning {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 10, height: 10)
                                Text("\(Int((dupEngine.scanProgress?.progressFraction ?? 0) * 100))%")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "38BDF8"))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "0284C7").opacity(0.2))
                            .cornerRadius(5)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 27)
                    .padding(.horizontal, 8)
                    .background(
                        selectedTab == tab ?
                        Color.white.opacity(0.12) :
                        Color.clear
                    )
                    .cornerRadius(7)
                    .overlay(
                        selectedTab == tab ?
                        RoundedRectangle(cornerRadius: 7)
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
        case .largeOldFiles: return "b"
        case .uninstaller: return "3"
        case .appUpdater: return "u"
        case .duplicateFinder: return "4"
        case .browserPrivacy: return "5"
        case .appLipo: return "6"
        case .developerVault: return "7"
        case .ghostDaemons: return "8"
        case .systemOptimize: return "9"
        case .startupManager: return "0"
        case .settings: return ","
        }
    }
    
    // MARK: - Üst İnce Durum Çubuğu
    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            Text(selectedTab.rawValue)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Eğer Çift Dosya Avcısı arka planda taranıyorsa ve kullanıcı başka menüdeyse:
            if dupEngine.isScanning && selectedTab != .duplicateFinder {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.55)
                        .tint(Color(hex: "38BDF8"))
                        .frame(width: 12, height: 12)
                    
                    Button(action: {
                        selectedTab = .duplicateFinder
                        HapticManager.shared.triggerClick()
                    }) {
                        HStack(spacing: 6) {
                            Text("Çift Dosyalar Taranıyor (\(Int((dupEngine.scanProgress?.progressFraction ?? 0) * 100))%)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "38BDF8"))
                            
                            if let path = dupEngine.scanProgress?.currentPath, !path.isEmpty {
                                Text("• " + (path as NSString).lastPathComponent)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)
                                    .frame(maxWidth: 180)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        dupEngine.cancelScan()
                        HapticManager.shared.triggerClick()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Çift Dosya Taramasını Durdur")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "0284C7").opacity(0.18))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "38BDF8").opacity(0.35), lineWidth: 1)
                )
            }
            
            Spacer()
            
            // Canlı İhyâ Sürüm / Güncelleme Rozeti
            headerUpdateStatusView
            
            // Satın Al / Pro Tanıtım Butonu (SADECE Pro Aktif Değilse Göster)
            if !licenseManager.isProUnlocked {
                Button(action: {
                    showProPromoModal = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "FDE047"))
                        Text("Pro Satın Al")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "7C3AED"), Color(hex: "D946EF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 5, y: 1)
                }
                .buttonStyle(.plain)
                .help("Ömür Boyu İhyâ Pro Lisansı Satın Al (sarkacadam.com)")
            } else if licenseManager.isTrialActive && !licenseManager.hasPersonalLicense {
                HStack(spacing: 5) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "38BDF8"))
                    Text("Pro Deneme (\(licenseManager.trialDaysRemaining) Gün)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "0284C7").opacity(0.25))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "38BDF8").opacity(0.4), lineWidth: 1)
                )
            }
            
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
    
    // MARK: - Üst Çubuk İhyâ Sürüm & Canlı Güncelleme Rozeti
    @ViewBuilder
    private var headerUpdateStatusView: some View {
        if updateChecker.updateAvailable {
            Button(action: {
                updateChecker.performDirectAutoUpdate()
                HapticManager.shared.triggerSuccess()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "FDE047"))
                    Text("v\(updateChecker.latestVersion) Güncelle")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "0284C7"), Color(hex: "2563EB")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .shadow(color: Color(hex: "0284C7").opacity(0.4), radius: 5, y: 1)
            }
            .buttonStyle(.plain)
            .help("Yeni İhyâ sürümü hazır! Tek tıkla güncellemek için tıklayın.")
        } else if updateChecker.isChecking {
            HStack(spacing: 5) {
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(Color(hex: "38BDF8"))
                    .frame(width: 10, height: 10)
                Text("Sürüm Kontrolü...")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(Color.white.opacity(0.04))
            .cornerRadius(6)
        } else {
            Button(action: {
                updateChecker.checkForUpdates(silent: false)
                HapticManager.shared.triggerClick()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "10B981"))
                    Text("v\(updateChecker.currentVersion) Güncel")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("İhyâ en güncel sürümde. Yeniden denetlemek için tıklayın.")
        }
    }
    
    // MARK: - Ana Sayfa İhyâ Güncelleme Bildirimi
    @ViewBuilder
    private var homeUpdateNotificationBanner: some View {
        if updateChecker.updateAvailable || updateChecker.isUpdating {
            HStack(spacing: 14) {
                // Parlayan 3D Rozet
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "0284C7"), Color(hex: "2563EB")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color(hex: "0284C7").opacity(0.4), radius: 6, y: 2)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Yeni İhyâ Sürümü Hazır:")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("v\(updateChecker.latestVersion)")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(hex: "38BDF8"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "0284C7").opacity(0.3))
                            .cornerRadius(5)
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Mevcut: v\(updateChecker.currentVersion)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    Text(updateChecker.releaseNotes.isEmpty ? "Mac'iniz için yeni performans ve derin arınma güncellemeleri yayınlandı." : updateChecker.releaseNotes)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Tek Tıkla Güncelle Butonu
                Button(action: {
                    updateChecker.performDirectAutoUpdate()
                    HapticManager.shared.triggerSuccess()
                }) {
                    HStack(spacing: 6) {
                        if updateChecker.isUpdating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                                .frame(width: 14, height: 14)
                            Text(updateChecker.updateStatusText.isEmpty ? "Güncelleniyor..." : updateChecker.updateStatusText)
                                .font(.system(size: 12, weight: .bold))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Şimdi Güncelle")
                                .font(.system(size: 12, weight: .bold))
                        }
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
                .disabled(updateChecker.isUpdating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "0A1628").opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "38BDF8").opacity(0.5), Color(hex: "2563EB").opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    // MARK: - Smart Clean Stage (Idle Hero vs Bento Grid)
    @ViewBuilder
    private var smartCleanStage: some View {
        VStack(spacing: 0) {
            // Ana Sayfa Canlı İhyâ Güncelleme Bildirimi
            homeUpdateNotificationBanner
            
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
                        icon: "shippingbox.and.arrow.backward.fill",
                        title: "Uygulama Kalıntıları ve Geliştirici Artıkları",
                        description: "Silinmiş programların yetim dosyalarını, Xcode derleme kalıntılarını ve paket önbelleklerini arındırır."
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
                    shortcutHint: engine.isScanning ? "Esc" : (engine.hasCleaned ? "⌘R" : "⌘↩"),
                    isPulsing: engine.isScanning || engine.isCleaning,
                    colorStyle: floatingButtonColorStyle
                ) {
                    HapticManager.shared.triggerClick()
                    if engine.isCleaning {
                        return // Halihazırda temizleme işlemi sürüyor
                    }
                    if engine.hasCleaned {
                        startSmartCleanScan()
                        return
                    }
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
}
    
    private func startSmartCleanScan() {
        engine.resetCleanedState()
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
            } else if engine.isCleaning {
                // Canlı Arındırma İşlem Rozeti
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(Color(hex: "10B981"))
                    Text("Arındırılıyor:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "34D399"))
                    Text(engine.currentTaskName.isEmpty ? "Önbellekler temizleniyor..." : engine.currentTaskName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color(hex: "064E3B").opacity(0.85))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "10B981").opacity(0.5), lineWidth: 1)
                )
                .transition(.opacity)
            } else if engine.hasCleaned {
                // Arındırma Tamamlandı Kutlama Rozeti
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "10B981"))
                    Text("Arındırma Başarıyla Tamamlandı!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("• \(engine.formattedLastFreed) disk alanı hafifletildi")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "34D399"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color(hex: "10B981").opacity(0.18))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "10B981").opacity(0.4), lineWidth: 1)
                )
                .transition(.opacity)
            }
            
            // ÜST BENTO SIRASI (3 KART)
            HStack(spacing: 16) {
                // 1. Kart: Sistem Temizliği
                let sysCat = engine.categories.first(where: { $0.category == .systemJunk })
                let isSysActive = engine.currentPhase == .systemJunk
                let isSysDone = engine.currentPhase != .idle && engine.currentPhase != .systemJunk
                let isSysCleaned = engine.hasCleaned && !engine.isScanning
                let sysBreakdown: [(name: String, size: String)] = {
                    if let c = sysCat, !c.items.isEmpty {
                        return c.items.prefix(3).map { ($0.name, $0.formattedSize) }
                    } else {
                        return [
                            (name: "Kullanıcı Önbelleği", size: isSysCleaned ? "Arındırıldı ✓" : "Önbellek"),
                            (name: "Sistem Günlükleri", size: isSysCleaned ? "Arındırıldı ✓" : "Raporlar"),
                            (name: "İndirilen DMG'ler", size: isSysCleaned ? "Arındırıldı ✓" : "Kalıplar")
                        ]
                    }
                }()
                
                BentoCardView(
                    title: "Sistem Arınması",
                    subtitle: isSysActive ? "Çöpler Taranıyor..." : (sysCat?.totalSize ?? 0 > 0 ? sysCat!.formattedSize : "Taramaya Hazır"),
                    statusText: isSysActive ? "Taranıyor..." : (isSysCleaned ? "Arındırıldı" : (isSysDone ? "Açılabilir Alan" : "Önbellek & Günlükler")),
                    isCompleted: isSysDone && (sysCat?.totalSize ?? 0 > 0 || engine.currentPhase == .completed),
                    isCleaned: isSysCleaned,
                    isActive: isSysActive,
                    emblemStyle: .emerald,
                    emblemIcon: "sparkles",
                    itemsBreakdown: sysBreakdown
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
                let isBrowserCleaned = engine.hasCleaned && !engine.isScanning
                let browserBreakdown: [(name: String, size: String)] = {
                    if let c = browserCat, !c.items.isEmpty {
                        return c.items.prefix(3).map { ($0.name, $0.formattedSize) }
                    } else {
                        return [
                            (name: "Safari Web Deposu", size: isBrowserCleaned ? "Arındırıldı ✓" : "Önbellek"),
                            (name: "Google Chrome & V8", size: isBrowserCleaned ? "Arındırıldı ✓" : "Veriler"),
                            (name: "Parolalar & Girişler", size: "Korunuyor ✓")
                        ]
                    }
                }()
                
                BentoCardView(
                    title: "Tarayıcı & Web",
                    subtitle: isBrowserActive ? "Web Taranıyor..." : (browserCat?.totalSize ?? 0 > 0 ? browserCat!.formattedSize : "Taramaya Hazır"),
                    statusText: isBrowserActive ? "Taranıyor..." : (isBrowserCleaned ? "Arındırıldı" : (isBrowserDone ? "Açılabilir Alan" : (engine.isScanning ? "Sırada bekliyor..." : "Safari, Chrome, Brave"))),
                    isCompleted: isBrowserDone && (browserCat?.totalSize ?? 0 > 0 || engine.currentPhase == .completed),
                    isCleaned: isBrowserCleaned,
                    isActive: isBrowserActive,
                    emblemStyle: .cyan,
                    emblemIcon: "globe",
                    itemsBreakdown: browserBreakdown
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
                let isUpCleaned = engine.hasCleaned && !engine.isScanning
                let updateBreakdown: [(name: String, size: String)] = {
                    if !engine.availableUpdates.isEmpty {
                        return engine.availableUpdates.prefix(3).map { ($0.appName, "v\($0.latestVersion)") }
                    } else {
                        let countStr = totalApps > 0 ? "\(totalApps) Yazılım" : "Tüm Sistem"
                        return [
                            (name: "Yüklü Sistem Yazılımları", size: "\(countStr) ✓"),
                            (name: "Sparkle Appcast Beslemeleri", size: "Güncel ✓"),
                            (name: "Homebrew & Paket Takibi", size: "Denetlendi ✓")
                        ]
                    }
                }()
                
                let upSubtitle: String = {
                    if isUpActive {
                        return "Sürümler Taranıyor..."
                    } else if updatesCount > 0 {
                        return "\(updatesCount) Güncelleme Mevcut"
                    } else if isUpDone {
                        return "Tüm Yazılımlar Güncel"
                    } else {
                        return "\(totalApps > 0 ? "\(totalApps)" : "46") Yazılım Denetimi"
                    }
                }()
                
                let upStatusText: String = {
                    if isUpActive {
                        return "Taranıyor..."
                    } else if updatesCount > 0 {
                        return "Güncellemeye Hazır"
                    } else if isUpDone {
                        return "\(totalApps > 0 ? "\(totalApps) Yazılım" : "Tüm Sistem") Güncel ✓"
                    } else if engine.isScanning {
                        return "Sırada bekliyor..."
                    } else {
                        return "Sparkle & Paket Takibi"
                    }
                }()
                
                BentoCardView(
                    title: "Uygulama & Güncelleme",
                    subtitle: upSubtitle,
                    statusText: upStatusText,
                    isCompleted: isUpDone,
                    isCleaned: isUpCleaned,
                    isActive: isUpActive,
                    emblemStyle: updatesCount > 0 ? .sapphire : (isUpDone ? .emerald : .sapphire),
                    emblemIcon: updatesCount > 0 ? "arrow.triangle.2.circlepath.circle.fill" : (isUpDone ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath.circle.fill"),
                    itemsBreakdown: updateBreakdown,
                    reviewButtonTitle: updatesCount > 0 ? "Güncelle" : "İncele"
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
                let isGhostCleaned = engine.hasCleaned && !engine.isScanning
                let ghostBreakdown: [(name: String, size: String)] = {
                    if !engine.ghostDaemons.isEmpty {
                        return engine.ghostDaemons.prefix(3).map { ($0.label, "Yetim Ajan") }
                    } else {
                        return [
                            (name: "LaunchAgents", size: "0 Tehdit ✓"),
                            (name: "LaunchDaemons", size: "0 Tehdit ✓"),
                            (name: "Pil Koruması", size: "Aktif ✓")
                        ]
                    }
                }()
                
                BentoCardView(
                    title: "Hayalet Servisler",
                    subtitle: isGhostActive ? "Ajanlar İnceleniyor..." : "\(engine.ghostDaemons.count) Tehdit",
                    statusText: isGhostActive ? "Taranıyor..." : (isGhostCleaned ? "Temizlendi" : (isGhostDone ? "Temizlenmeye Hazır" : (engine.isScanning ? "Sırada bekliyor..." : "Pil Koruması Tam"))),
                    isCompleted: isGhostDone,
                    isCleaned: isGhostCleaned,
                    isActive: isGhostActive,
                    emblemStyle: .violet,
                    emblemIcon: "bolt.shield.fill",
                    itemsBreakdown: ghostBreakdown
                ) {
                    selectedTab = .ghostDaemons
                    HapticManager.shared.triggerClick()
                }
                .frame(maxWidth: .infinity)

                // 5. Kart: Uygulama Artıkları (Yetim Kayıtlar)
                let orphanCat = engine.categories.first(where: { $0.category == .appResidues })
                let isOrphanActive = engine.currentPhase == .appLipo && engine.isScanning
                let isOrphanDone = engine.currentPhase == .completed
                let isOrphanCleaned = engine.hasCleaned && !engine.isScanning
                let orphanSize = orphanCat?.totalSize ?? 0
                let orphanBreakdown: [(name: String, size: String)] = {
                    if let c = orphanCat, !c.items.isEmpty {
                        return c.items.prefix(3).map { ($0.name, $0.formattedSize) }
                    } else {
                        return [
                            (name: "Silinen Yazılımlar", size: isOrphanCleaned ? "Arındırıldı ✓" : "App Support"),
                            (name: "Yetim Tercihler", size: isOrphanCleaned ? "Arındırıldı ✓" : ".plist"),
                            (name: "Eski Kalıntılar", size: isOrphanCleaned ? "Arındırıldı ✓" : "Temiz ✓")
                        ]
                    }
                }()
                
                BentoCardView(
                    title: "Uygulama Artıkları",
                    subtitle: isOrphanActive ? "Kalıntılar Taranıyor..." : (orphanSize > 0 ? orphanCat!.formattedSize : "Artık Kayıt Yok"),
                    statusText: isOrphanActive ? "Taranıyor..." : (isOrphanCleaned ? "Arındırıldı" : (orphanSize > 0 ? "Açılabilir Alan" : (engine.isScanning ? "Sırada bekliyor..." : "Silinmiş Program Artıkları"))),
                    isCompleted: isOrphanDone && orphanSize > 0,
                    isCleaned: isOrphanCleaned,
                    isActive: isOrphanActive,
                    emblemStyle: .rose,
                    emblemIcon: "shippingbox.and.arrow.backward.fill",
                    itemsBreakdown: orphanBreakdown
                ) {
                    if let c = orphanCat, c.totalSize > 0 {
                        withAnimation(.spring()) { selectedCategoryForXRay = c }
                        HapticManager.shared.triggerClick()
                    } else {
                        selectedTab = .uninstaller
                        HapticManager.shared.triggerClick()
                    }
                }
                .frame(maxWidth: .infinity)
                
                // 6. Kart: Geliştirici Kasası
                let devCat = engine.categories.first(where: { $0.category == .developerVault })
                let isDevActive = engine.currentPhase == .developerVault
                let isDevDone = engine.currentPhase == .completed
                let isDevCleaned = engine.hasCleaned && !engine.isScanning
                let devBreakdown: [(name: String, size: String)] = {
                    if let c = devCat, !c.items.isEmpty {
                        return c.items.prefix(3).map { ($0.name, $0.formattedSize) }
                    } else {
                        return [
                            (name: "Xcode DerivedData", size: isDevCleaned ? "Arındırıldı ✓" : "Önbellek"),
                            (name: "Docker & Simülatör", size: isDevCleaned ? "Arındırıldı ✓" : "İmajlar"),
                            (name: "npm, pip, Paketler", size: isDevCleaned ? "Arındırıldı ✓" : "Depolar")
                        ]
                    }
                }()
                
                BentoCardView(
                    title: "Geliştirici Kasası",
                    subtitle: isDevActive ? "Önbellekler Taranıyor..." : (devCat?.totalSize ?? 0 > 0 ? devCat!.formattedSize : "Taramaya Hazır"),
                    statusText: isDevActive ? "Taranıyor..." : (isDevCleaned ? "Arındırıldı" : (isDevDone ? "Açılabilir Alan" : (engine.isScanning ? "Sırada bekliyor..." : "Xcode, Docker, Node"))),
                    isCompleted: isDevDone && (devCat?.totalSize ?? 0 > 0 || engine.currentPhase == .completed),
                    isCleaned: isDevCleaned,
                    isActive: isDevActive,
                    emblemStyle: .amber,
                    emblemIcon: "hammer.fill",
                    itemsBreakdown: devBreakdown
                ) {
                    if let c = devCat {
                        withAnimation(.spring()) { selectedCategoryForXRay = c }
                        HapticManager.shared.triggerClick()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            
            // Alt Bilgi Şeridi: Şahsî Dosya Güvenliği Güvencesi
            if !engine.isScanning {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(Color(hex: "34D399"))
                        .font(.system(size: 13))
                    
                    Text("GÜVENLİK PROTOKOLÜ:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "34D399"))
                    
                    Text("Fotoğraflarınız, videolarınız ve şahsî belgeleriniz ASLA silinmez. Sadece sistem çöpleri, web önbellekleri ve yetim artıklar arındırılır.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color(hex: "10B981").opacity(0.12))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "10B981").opacity(0.25), lineWidth: 1)
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
        if engine.isCleaning { return "Arındırılıyor..." }
        if engine.hasCleaned { return "Yeniden Tara" }
        if engine.totalReclaimableBytes > 0 { return "Arındır (\(engine.formattedTotalReclaimable))" }
        return "Sistemi Tara"
    }
    
    private var floatingButtonIcon: String {
        if engine.isScanning { return "stop.fill" }
        if engine.isCleaning { return "sparkles" }
        if engine.hasCleaned { return "arrow.clockwise" }
        if engine.totalReclaimableBytes > 0 { return "sparkles" }
        return "radar"
    }
    
    private var floatingButtonColorStyle: FloatingActionButton.ColorStyle {
        if engine.isScanning { return .dangerStop }
        if engine.isCleaning { return .freshMint }
        if engine.hasCleaned { return .successEmerald }
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Geliştirici Kasası Sonuçları")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            let totalDevSize = items.reduce(0) { $0 + $1.size }
                            Text("\(items.count) Öğe • Toplam: \(ByteCountFormatter.string(fromByteCount: totalDevSize, countStyle: .file))")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        
                        Button(action: {
                            Task {
                                _ = await engine.performCleanCategory(.developerVault)
                                SoundManager.shared.playCleanFinished()
                                HapticManager.shared.triggerSuccess()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Geliştirici Artıklarını Temizle")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(color: Color(hex: "F59E0B").opacity(0.3), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(items) { item in
                                HStack(spacing: 12) {
                                    Button(action: {
                                        engine.toggleItemSelection(categoryType: .developerVault, itemId: item.id)
                                        HapticManager.shared.triggerClick()
                                    }) {
                                        Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 15))
                                            .foregroundColor(item.isSelected ? Color(hex: "F59E0B") : .white.opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Image(systemName: "hammer.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(item.name)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Text(item.safety.displayName)
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "8B5CF6").opacity(0.2))
                                                .foregroundColor(Color(hex: "C4B5FD"))
                                                .cornerRadius(4)
                                        }
                                        
                                        Text(item.path)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.45))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                                    }) {
                                        Image(systemName: "arrow.up.forward.app")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Finder'da Göster")
                                    
                                    Text(item.formattedSize)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tespit Edilen Hayalet Servisler")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(engine.ghostDaemons.count) Ölü Servis Bulundu • Arka Planda Pil ve CPU Tüketimini Önleyin")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        
                        Button(action: {
                            engine.removeAllGhostDaemons()
                            SoundManager.shared.playCleanFinished()
                            HapticManager.shared.triggerSuccess()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Tümünü Yok Et")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(color: Color(hex: "EF4444").opacity(0.3), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(engine.ghostDaemons) { ghost in
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hex: "FBBF24"))
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ghost.label)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 4) {
                                            Text("Ölü Hedef:")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(Color(hex: "FB7185"))
                                            Text(ghost.missingBinaryPath)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(Color(hex: "FDA4AF"))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        
                                        Text(ghost.plistPath)
                                            .font(.system(size: 9.5, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        NSWorkspace.shared.selectFile(ghost.plistPath, inFileViewerRootedAtPath: "")
                                    }) {
                                        Image(systemName: "arrow.up.forward.app")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Finder'da Göster")
                                    
                                    Button(action: {
                                        engine.removeGhostDaemon(ghost: ghost)
                                        SoundManager.shared.playCardComplete()
                                        HapticManager.shared.triggerSuccess()
                                    }) {
                                        Text("Yok Et")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "EF4444"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color(hex: "EF4444").opacity(0.15))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color(hex: "EF4444").opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "EF4444").opacity(0.15), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Budanabilecek Evrensel Uygulamalar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            let totalLipo = engine.lipoCandidates.reduce(0) { $0 + $1.reclaimableSize }
                            Text("+\(ByteCountFormatter.string(fromByteCount: totalLipo, countStyle: .file)) Alan Açılabilir • M-Serisi Saf ARM64 Hızı")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "34D399"))
                        }
                        Spacer()
                        
                        Button(action: {
                            Task {
                                _ = await engine.thinAllLipoItems()
                                SoundManager.shared.playCleanFinished()
                                HapticManager.shared.triggerSuccess()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "scissors")
                                Text("Tümünü Güvenle Buda")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "F43F5E"), Color(hex: "E11D48")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(color: Color(hex: "F43F5E").opacity(0.3), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                    
                    // Apple Gatekeeper Güvenlik Kalkanı Bilgilendirmesi
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "38BDF8"))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Gatekeeper & Kod İmzası Bütünlüğü Korumalı")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Text("İhyâ, Intel (x86_64) kod dilimini budadıktan sonra uygulamayı yerel ad-hoc sertifikayla otomatik olarak yeniden imzalar. Böylece macOS Gatekeeper çökmesi yaşanmaz ve uygulamanız saf Apple Silicon performansı kazanır.")
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
                    
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(engine.lipoCandidates) { item in
                                HStack(spacing: 14) {
                                    // Gerçek Uygulama İkonu (Native macOS App Icon)
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.appPath))
                                        .resizable()
                                        .frame(width: 36, height: 36)
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(item.appName)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Text("Universal 2")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color(hex: "38BDF8").opacity(0.2))
                                                .foregroundColor(Color(hex: "7DD3FC"))
                                                .cornerRadius(4)
                                        }
                                        
                                        Text(item.appPath)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.45))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("+\(item.formattedReclaimable)")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(hex: "34D399"))
                                        Text("Intel Tasarrufu")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.45))
                                    }
                                    
                                    Button(action: {
                                        NSWorkspace.shared.selectFile(item.appPath, inFileViewerRootedAtPath: "")
                                    }) {
                                        Image(systemName: "arrow.up.forward.app")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Finder'da Göster")
                                    
                                    Button(action: {
                                        Task {
                                            _ = await engine.thinLipoItem(item: item)
                                            SoundManager.shared.playCleanFinished()
                                            HapticManager.shared.triggerSuccess()
                                        }
                                    }) {
                                        Text("Buda")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(hex: "F43F5E"))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
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
                        
                        Text(licenseManager.hasPersonalLicense ? "Ömür Boyu VIP" : (licenseManager.isTrialActive ? "Pro Deneme (\(licenseManager.trialDaysRemaining) Gün)" : "Ücretsiz"))
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(licenseManager.hasPersonalLicense ? Color(hex: "7C3AED") : (licenseManager.isTrialActive ? Color(hex: "2563EB") : Color.white.opacity(0.12)))
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

                    if !licenseManager.hasPersonalLicense {
                        HStack {
                            Spacer()
                            Link("VIP Satın Al (3'lü Taş Seti Hediyeli) ↗", destination: URL(string: "https://sarkacadam.com/urun/ihya-sukunet-kristal-seti")!)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "F59E0B"))
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color(hex: "10B981"))
                                .font(.system(size: 12))
                            Text("Bu donanım için Ömür Boyu VIP Lisansı aktif durumdadır. Yeniden satın alma gerekmez.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding(.vertical, 4)
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
                
                // İhyâ Sürüm ve Otomatik Güncelleme Kartı
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("İhyâ Sürüm ve Güncelleme")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Mevcut: v\(updateChecker.currentVersion) • Apple Silicon & Intel Universal 2")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        Spacer()
                        
                        if updateChecker.updateAvailable {
                            Text("YENİ SÜRÜM v\(updateChecker.latestVersion)")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "10B981"))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        } else {
                            Text("GÜNCEL")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            updateChecker.checkForUpdates(silent: false)
                        }) {
                            HStack(spacing: 6) {
                                if updateChecker.isChecking {
                                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                                    Text("Denetleniyor...")
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Güncellemeleri Denetle")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(updateChecker.isChecking || updateChecker.isUpdating)
                        
                        if updateChecker.updateAvailable {
                            Button(action: {
                                updateChecker.performDirectAutoUpdate()
                            }) {
                                HStack(spacing: 6) {
                                    if updateChecker.isUpdating {
                                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                                        Text(updateChecker.updateStatusText.isEmpty ? "Yükleniyor..." : updateChecker.updateStatusText)
                                    } else {
                                        Image(systemName: "sparkles")
                                        Text("v\(updateChecker.latestVersion) Tek Tıkla Güncelle")
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    if let msg = updateChecker.checkCompletedMessage {
                        Text(msg)
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

                // macOS İzinleri ve Tam Disk Erişimi Kartı
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("macOS Güvenlik ve Tam Disk Erişimi")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Sistem önbellekleri ve artık dosyaların eksiksiz taranabilmesi için gereklidir.")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        Spacer()
                        
                        let hasFDA = FDAChecker.hasFullDiskAccess()
                        Text(hasFDA ? "AKTİF ✓" : "İZİN GEREKİYOR")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(hasFDA ? Color(hex: "10B981") : Color(hex: "F59E0B"))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    if !FDAChecker.hasFullDiskAccess() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• İhyâ'nın korumalı sistem dosyalarını tarayabilmesi için macOS izni tanımlanmalıdır.")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.75))
                            Text("• Sistem Ayarları'nda İhyâ görünmüyorsa; sol alttaki '+' butonuna tıklayıp Uygulamalar'dan İhyâ'yı seçin veya 'Finder'da Göster' butonuna basarak simgeyi doğrudan pencereye sürükleyin.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "FBBF24"))
                                .lineSpacing(2)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            FDAChecker.openSystemSettings()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                Text("Sistem Ayarlarını Aç")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: {
                            FDAChecker.revealInFinder()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                Text("Finder'da İhyâ'yı Göster (Sürükle)")
                            }
                        }
                        .buttonStyle(.bordered)
                        .help("İhyâ uygulamasını Finder'da seçer. Açılan Sistem Ayarları penceresine doğrudan sürükleyip bırakabilirsiniz.")
                        
                        Button(action: {
                            FDAChecker.openAppManagementSettings()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Uygulama Yönetimi İzni")
                            }
                        }
                        .buttonStyle(.bordered)
                        .help("macOS Uygulama Yönetimi ayarlarını açar. İhyâ'nın diğer yazılımları tek tıkla güncellemesi için bu listede aktif olmalıdır.")
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
                
                // Geliştirici & İletişim Kartı (Kâşif Standardı)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Geliştirici & İletişim")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 24) {
                        // Sütun 1: Kişi & Telefon
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(Color(hex: "38BDF8"))
                                    .font(.system(size: 12))
                                    .frame(width: 14)
                                Text("Sarkaç Adam")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(Color(hex: "38BDF8"))
                                    .font(.system(size: 12))
                                    .frame(width: 14)
                                Link("0532 630 88 77", destination: URL(string: "tel://05326308877")!)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "38BDF8"))
                            }
                        }
                        
                        Divider()
                            .frame(height: 38)
                            .background(Color.white.opacity(0.12))
                        
                        // Sütun 2: E-posta & Web Siteleri
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(Color(hex: "38BDF8"))
                                    .font(.system(size: 12))
                                    .frame(width: 14)
                                Link("info@caneser.com", destination: URL(string: "mailto:info@caneser.com")!)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .foregroundColor(Color(hex: "38BDF8"))
                                    .font(.system(size: 12))
                                    .frame(width: 14)
                                HStack(spacing: 6) {
                                    Link("caneser.com", destination: URL(string: "https://caneser.com")!)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "38BDF8"))
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.3))
                                    Link("sarkacadam.com", destination: URL(string: "https://sarkacadam.com")!)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.vertical, 2)
                    
                    Text("macOS Sonoma ve Sequoia için saf Swift, Metal & POSIX mimarisiyle geliştirilmiştir. Tüm hakları saklıdır.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
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
    
    // MARK: - İlk Açılış Pro Tanıtım Kontrolü
    private func checkFirstRunPromo() {
        let hasSeenPromo = UserDefaults.standard.bool(forKey: "ihya_has_seen_pro_onboarding")
        if !hasSeenPromo && !licenseManager.hasPersonalLicense {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showProPromoModal = true
                }
            }
        }
    }
    
    // MARK: - Pro Tanıtım & Satın Alma Modalı (Paywall / Onboarding Popup)
    private var proPromoModalOverlay: some View {
        ZStack {
            // Karartılmış Zemin
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showProPromoModal = false
                        UserDefaults.standard.set(true, forKey: "ihya_has_seen_pro_onboarding")
                    }
                }
            
            // Cam Pencere
            VStack(spacing: 16) {
                // Kapat Butonu (Sağ Üst)
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showProPromoModal = false
                            UserDefaults.standard.set(true, forKey: "ihya_has_seen_pro_onboarding")
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                // Başlık & İkon
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "7C3AED"), Color(hex: "38BDF8")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .shadow(color: Color(hex: "7C3AED").opacity(0.5), radius: 14)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("İhyâ Pro — Mac'iniz İçin Kusursuz Arındırma")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Sarkaç Adam özel mühendisliği ile geliştirilen tüm üstün yetenekleri tek lisansla ömür boyu kullanın.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }
                
                // Yetenek Listesi (Bento Kartları)
                VStack(spacing: 6) {
                    promoFeatureRow(icon: "bolt.fill", colorHex: "14B8A6", title: "Akıllı & Derin Sistem Arındırma", desc: "Geçici sistem yükleri, DNS ve birleşik RAM'i tek tıkla boşaltır.")
                    promoFeatureRow(icon: "doc.on.doc.fill", colorHex: "38BDF8", title: "Çift Dosya Avcısı (SHA-256)", desc: "Mükerrer fotoğraf, video ve belgeleri kriptografik eşler, diski açar.")
                    promoFeatureRow(icon: "circle.hexagongrid.fill", colorHex: "06B6D4", title: "Hacim Röntgeni (Sunburst)", desc: "Diskinizi renkli halkalarla haritalandırır, devasa gizli klasörleri yakalar.")
                    promoFeatureRow(icon: "xmark.bin.fill", colorHex: "EF4444", title: "Kalıntısız Uygulama Kaldırıcı", desc: "Uygulamaları ve tüm gizli kütüphane kırıntılarını 360° derin temizler.")
                    promoFeatureRow(icon: "bolt.shield.fill", colorHex: "8B5CF6", title: "Hayalet Servis Kalkanı", desc: "Arka planda pil ve CPU tüketen yetim servis süreçlerini yok eder.")
                }
                .padding(.horizontal, 4)
                
                // VIP Hediye & Lisans Güvencesi Rozeti
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(Color(hex: "FDE047"))
                        .font(.system(size: 11))
                    Text("Ömür Boyu Lisans • Sıfır Abonelik • 3'lü Doğal Kristal Taş Seti Hediyeli")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Color(hex: "FDE047"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "FDE047").opacity(0.12))
                .cornerRadius(6)
                
                // Butonlar
                VStack(spacing: 8) {
                    Button(action: {
                        if let url = URL(string: "https://sarkacadam.com/urun/ihya-sukunet-kristal-seti") {
                            NSWorkspace.shared.open(url)
                        }
                        showProPromoModal = false
                        UserDefaults.standard.set(true, forKey: "ihya_has_seen_pro_onboarding")
                    }) {
                        HStack(spacing: 6) {
                            Text("Ömür Boyu Pro Lisans Satın Al (sarkacadam.com) ↗")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "7C3AED"), Color(hex: "9333EA")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 14) {
                        Button(action: {
                            selectedTab = .settings
                            showProPromoModal = false
                            UserDefaults.standard.set(true, forKey: "ihya_has_seen_pro_onboarding")
                        }) {
                            Text("Zaten Lisansım Var (Etkinleştir)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "38BDF8"))
                        }
                        .buttonStyle(.plain)
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        
                        Button(action: {
                            showProPromoModal = false
                            UserDefaults.standard.set(true, forKey: "ihya_has_seen_pro_onboarding")
                        }) {
                            Text("Daha Sonra")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0D081B").opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "7C3AED").opacity(0.6), Color(hex: "38BDF8").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.7), radius: 32, y: 12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private func promoFeatureRow(icon: String, colorHex: String, title: String, desc: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: colorHex).opacity(0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: colorHex))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(hex: "10B981"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
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
