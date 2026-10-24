import SwiftUI
import AppKit
import IhyaCore

public struct BrowserPrivacyView: View {
    @State private var browsers: [DetectedBrowser] = []
    @State private var selectedBrowserId: String? = nil
    @State private var isScanning: Bool = false
    @State private var hasScanned: Bool = false
    @State private var isCleaning: Bool = false
    @State private var statusToast: String? = nil
    @State private var showPasswordWarningAlert: Bool = false
    
    public init() {}
    
    private var selectedBrowser: DetectedBrowser? {
        if let id = selectedBrowserId {
            return browsers.first(where: { $0.id == id })
        }
        return browsers.first
    }
    
    private var totalSelectedReclaimable: Int64 {
        browsers.reduce(0) { $0 + $1.totalSelectedSize }
    }
    
    private var selectedBrowsersCount: Int {
        browsers.filter { $0.totalSelectedSize > 0 }.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningIndicatorView
            } else if !hasScanned {
                idleHeroStageView
            } else if browsers.isEmpty {
                emptyResultView
            } else {
                // Üst Yönetim Çubuğu
                topControlToolbar
                
                // Bölünmüş Sahne (Sol: Tarayıcılar Listesi, Sağ: Granüler Alt Kategoriler)
                HStack(spacing: 0) {
                    // Sol Panel: Tespit Edilen Tarayıcılar
                    browsersSidebarList
                        .frame(width: 320)
                    
                    Divider()
                        .background(Color.white.opacity(0.08))
                    
                    // Sağ Panel: Detaylı Röntgen Çekmecesi
                    if let browser = selectedBrowser {
                        browserDetailInspector(browser: browser)
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer()
                    }
                }
                
                // Alt Eylem Çubuğu
                bottomActionToolbar
            }
        }
        .alert("Kayıtlı Tarayıcı Parolaları Silinsin mi?", isPresented: $showPasswordWarningAlert) {
            Button("Parolaları Sil ve Arındır", role: .destructive) {
                performCleaning()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Seçili tarayıcılardaki kayıtlı web sitesi kullanıcı adı ve giriş parolalarınız kalıcı olarak silinecektir. Bu işlem geri alınamaz. Devam etmek istediğinize emin misiniz?")
        }
        .onAppear {
            if !hasScanned && !isScanning {
                runScan()
            }
        }
    }
    
    // MARK: - 1. Boşta / Hero Sahnesi
    private var idleHeroStageView: some View {
        HeroStageView(
            title: "Tarayıcı & Web Gizlilik Kasası",
            subtitle: "Safari, Chrome, Firefox, Brave ve Arc tarayıcılarında biriken gigabaytlarca önbelleği, V8 derlenmiş kod depolarını ve izleme kalıntılarını arındırın.",
            emblemStyle: .cyan,
            emblemIcon: "globe",
            bullets: [
                .init(
                    icon: "lock.shield.fill",
                    title: "Güvenli Varsayılanlar & Seçmeli Kontrol",
                    description: "Kayıtlı şifreleriniz, yer imleriniz ve oturum çerezleriniz varsayılan olarak korunur. Dilediğiniz kategoriyi serbestçe seçip arındırabilirsiniz."
                ),
                .init(
                    icon: "bolt.fill",
                    title: "V8 Kod ve WebKit Motoru Hızlandırma",
                    description: "Sitelerin arkada bıraktığı bayt kodlarını ve çakışan geçici dosyaları sıfırlayarak tarayıcıları ilk günkü hızına kavuşturur."
                ),
                .init(
                    icon: "slider.horizontal.3",
                    title: "Granüler ve Şeffaf Röntgen",
                    description: "Her tarayıcının IndexedDB, Service Worker, çerez ve geçmiş boyutlarını tek tek inceleyin; tam kontrol sizin elinizde olsun."
                )
            ],
            targetDiskInfo: "Safari, Google Chrome, Firefox, Brave, Arc, Edge, Opera, Vivaldi",
            buttonTitle: "Tarayıcıları Derinlemesine İncele",
            buttonColorStyle: .electricCyan,
            onAction: {
                runScan()
            }
        )
    }
    
    // MARK: - 2. Tarama İlerleme Göstergesi
    private var scanningIndicatorView: some View {
        LuxuryScanningStageView(
            title: "Tarayıcılar ve Gizlilik Verileri Taranıyor...",
            subtitle: "Safari • Google Chrome • Brave • Arc • Firefox • Web Depoları",
            emblemStyle: .sapphire,
            emblemIcon: "globe",
            steps: ["1. Profil Tespiti", "2. Önbellek & Çerez Analizi", "3. Hacim Hesabı"],
            currentStepIndex: 1,
            progressFraction: 0.65,
            currentItemName: "Safari, Google Chrome, Arc, Brave önbellekleri inceleniyor..."
        )
    }
    
    // MARK: - 3. Boş Sonuç Görünümü
    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "10B981"))
            
            Text("Harika! Tarayıcılarınız Zaten Tertemiz.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Sisteminizdeki tarayıcılarda şişkinlik veya temizlenmesi gereken önbellek bulunamadı.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            Button("Yeniden Tara") {
                runScan()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
    }
    
    // MARK: - 4. Üst Yönetim Çubuğu
    private var topControlToolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tespit Edilen Tarayıcılar")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                let totalReclaimable = browsers.reduce(0) { $0 + $1.totalSize }
                Text("\(browsers.count) Tarayıcı Kurulu • Toplam \(ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file)) Alan")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: {
                runScan()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Yeniden Tara")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.15))
    }
    
    // MARK: - 5. Sol Panel: Tarayıcılar Listesi
    private var browsersSidebarList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(browsers) { browser in
                    let isCurrentSelected = selectedBrowser?.id == browser.id
                    
                    Button(action: {
                        selectedBrowserId = browser.id
                        HapticManager.shared.triggerClick()
                    }) {
                        HStack(spacing: 12) {
                            // Tarayıcının Gerçek Uygulama Simgesi
                            if let iconImg = appIconImage(for: browser.appPath, bundleId: browser.bundleId) {
                                Image(nsImage: iconImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "06B6D4"))
                                    .frame(width: 32, height: 32)
                            }
                            
                            // İsim ve Çalışma Durumu
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(browser.name)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    if browser.isRunning {
                                        Circle()
                                            .fill(Color(hex: "10B981"))
                                            .frame(width: 6, height: 6)
                                            .help("Tarayıcı şu anda açık")
                                    }
                                }
                                
                                Text(browser.isRunning ? "Açık / Çalışıyor" : "Kapalı")
                                    .font(.system(size: 9))
                                    .foregroundColor(browser.isRunning ? Color(hex: "34D399") : .white.opacity(0.45))
                            }
                            
                            Spacer()
                            
                            // Boyut
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(browser.formattedSelectedSize)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(browser.totalSelectedSize > 0 ? Color(hex: "38BDF8") : .white.opacity(0.4))
                                
                                Text("\(browser.items.filter { $0.isSelected }.count) / \(browser.items.count) Öğe")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isCurrentSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isCurrentSelected ? Color(hex: "06B6D4").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(14)
        }
    }
    
    // MARK: - 6. Sağ Panel: Detaylı Röntgen Çekmecesi
    private func browserDetailInspector(browser: DetectedBrowser) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Başlık Kartı
            HStack(spacing: 14) {
                if let iconImg = appIconImage(for: browser.appPath, bundleId: browser.bundleId) {
                    Image(nsImage: iconImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(browser.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if browser.isRunning {
                            Text("AÇIK")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "10B981").opacity(0.2))
                                .foregroundColor(Color(hex: "34D399"))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(browser.appPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if browser.isRunning {
                    Button(action: {
                        quitRunningBrowser(bundleId: browser.bundleId)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                            Text("Tarayıcıyı Kapat")
                        }
                        .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            
            // Güvenlik Güvencesi Bilgilendirmesi
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(Color(hex: "34D399"))
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Akıllı Koruma & Güvenli Varsayılanlar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Kayıtlı parolalarınız, açık oturum çerezleriniz ve form geçmişiniz varsayılan olarak korunur. Yalnızca siz açıkça işaretlerseniz arındırılır.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(12)
            .background(Color(hex: "10B981").opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "10B981").opacity(0.2), lineWidth: 1)
            )
            
            // Alt Kategoriler Başlık & Toplu Seçim Çubuğu
            HStack {
                Text("TEMİZLEME ALANLARI (İSTEĞE BAĞLI SEÇİLEBİLİR)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                
                Spacer()
                
                let nonPasswordItems = browser.items.filter { $0.type != .passwords }
                let allSelected = !nonPasswordItems.isEmpty && nonPasswordItems.allSatisfy { $0.isSelected }
                
                Button(action: {
                    setAllItems(browserId: browser.id, selected: !allSelected)
                }) {
                    Text(allSelected ? "Seçimi Kaldır" : "Tümünü Seç (Şifreler Hariç)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "38BDF8"))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // Alt Kategoriler Listesi
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(browser.items) { item in
                        let isCrit = item.type.isCritical
                        
                        HStack(spacing: 12) {
                            // Seçim Kutusu
                            Toggle("", isOn: Binding(
                                get: { item.isSelected },
                                set: { newValue in
                                    toggleSubItem(browserId: browser.id, itemId: item.id, newValue: newValue)
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            
                            // İkon
                            Image(systemName: item.type.icon)
                                .font(.system(size: 14))
                                .foregroundColor(
                                    isCrit ? Color(hex: "EF4444") :
                                    item.type.isCaution ? Color(hex: "F59E0B") : Color(hex: "06B6D4")
                                )
                                .frame(width: 24)
                            
                            // İsim & Açıklama
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(isCrit ? (item.isSelected ? Color(hex: "FCA5A5") : .white) : .white)
                                    
                                    if let warn = item.type.warningNote {
                                        Text(warn)
                                            .font(.system(size: 9, weight: isCrit ? .bold : .regular))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(
                                                isCrit ? Color(hex: "EF4444").opacity(0.2) : Color(hex: "F59E0B").opacity(0.15)
                                            )
                                            .foregroundColor(isCrit ? Color(hex: "F87171") : Color(hex: "FBBF24"))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(item.descriptionText)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            // Boyut
                            Text(item.formattedSize)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(item.size > 0 ? .white.opacity(0.85) : .white.opacity(0.4))
                        }
                        .padding(10)
                        .background(
                            isCrit ?
                            (item.isSelected ? Color(hex: "EF4444").opacity(0.12) : Color(hex: "EF4444").opacity(0.04)) :
                            Color.white.opacity(0.03)
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isCrit ? (item.isSelected ? Color(hex: "EF4444").opacity(0.6) : Color(hex: "EF4444").opacity(0.25)) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
        .padding(16)
    }
    
    // MARK: - 7. Alt Sabit Eylem Çubuğu
    private var bottomActionToolbar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "10B981"))
                Text("\(selectedBrowsersCount) Tarayıcı Seçili • \(ByteCountFormatter.string(fromByteCount: totalSelectedReclaimable, countStyle: .file)) Alan Açılabilir")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Spacer()
            
            if let toast = statusToast {
                Text(toast)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "34D399"))
                    .transition(.opacity)
            }
            
            Button(action: {
                handleCleanButtonTap()
            }) {
                HStack(spacing: 6) {
                    if isCleaning {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Seçilen Tarayıcıları Arındır (\(ByteCountFormatter.string(fromByteCount: totalSelectedReclaimable, countStyle: .file)))")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    totalSelectedReclaimable > 0 ?
                    Color(hex: "0891B2") : Color.white.opacity(0.12)
                )
                .cornerRadius(10)
                .shadow(color: totalSelectedReclaimable > 0 ? Color(hex: "06B6D4").opacity(0.4) : .clear, radius: 8, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(totalSelectedReclaimable == 0 || isCleaning)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.25))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - İş Mantığı ve Eylemler
    private func runScan() {
        isScanning = true
        Task {
            let detected = await BrowserCacheEngine.shared.detectInstalledBrowsers()
            await MainActor.run {
                self.browsers = detected
                if self.selectedBrowserId == nil || !detected.contains(where: { $0.id == self.selectedBrowserId }) {
                    self.selectedBrowserId = detected.first?.id
                }
                self.isScanning = false
                self.hasScanned = true
            }
        }
    }
    
    private func toggleSubItem(browserId: String, itemId: String, newValue: Bool) {
        if let bIndex = browsers.firstIndex(where: { $0.id == browserId }) {
            if let iIndex = browsers[bIndex].items.firstIndex(where: { $0.id == itemId }) {
                browsers[bIndex].items[iIndex].isSelected = newValue
                if newValue && browsers[bIndex].items[iIndex].type == .passwords {
                    HapticManager.shared.triggerWarning()
                } else {
                    HapticManager.shared.triggerClick()
                }
            }
        }
    }
    
    private func setAllItems(browserId: String, selected: Bool) {
        if let bIndex = browsers.firstIndex(where: { $0.id == browserId }) {
            for i in 0..<browsers[bIndex].items.count {
                // Güvenlik Kalkanı: "Tümünü Seç" dense dahi şifreler kullanıcı bizzat kutucuğa basmadıkça işaretlenmez!
                if browsers[bIndex].items[i].type == .passwords && selected {
                    continue
                }
                browsers[bIndex].items[i].isSelected = selected
            }
        }
    }
    
    private func quitRunningBrowser(bundleId: String) {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in apps {
            app.terminate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            runScan()
        }
    }
    
    private func handleCleanButtonTap() {
        let hasSelectedPasswords = browsers.contains(where: { $0.items.contains(where: { $0.isSelected && $0.type == .passwords }) })
        if hasSelectedPasswords {
            showPasswordWarningAlert = true
        } else {
            performCleaning()
        }
    }
    
    private func performCleaning() {
        isCleaning = true
        Task {
            var itemsToClean: [BrowserSubItem] = []
            for b in browsers {
                for item in b.items where item.isSelected {
                    itemsToClean.append(item)
                }
            }
            
            let freed = await BrowserCacheEngine.shared.cleanBrowserItems(items: itemsToClean)
            SoundManager.shared.playCleanFinished()
            HapticManager.shared.triggerSuccess()
            
            await MainActor.run {
                self.statusToast = "+\(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)) Başarıyla Temizlendi!"
                self.isCleaning = false
            }
            
            // Listeyi yeniden tara
            try? await Task.sleep(nanoseconds: 800_000_000)
            runScan()
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                self.statusToast = nil
            }
        }
    }
    
    private func appIconImage(for path: String, bundleId: String) -> NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        } else if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}
