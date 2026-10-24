import SwiftUI
import AppKit
import IhyaCore

public enum AppFilterType: String, CaseIterable, Identifiable {
    case all = "Tüm Uygulamalar"
    case userApps = "Kullanıcı"
    case orphans = "Yetim Kalıntılar"
    
    public var id: String { rawValue }
}

public struct AppUninstallerView: View {
    @State private var installedApps: [InstalledAppItem] = []
    @State private var orphanedGroups: [OrphanedRemnantGroup] = []
    @State private var isScanning: Bool = false
    @State private var hasScanned: Bool = false
    @State private var searchQuery: String = ""
    @State private var selectedFilter: AppFilterType = .all
    @State private var expandedAppIds: Set<String> = []
    @State private var showConfirmDialog: Bool = false
    @State private var isProcessingTrash: Bool = false
    @State private var statusToast: String? = nil
    
    public init() {}
    
    private var filteredApps: [InstalledAppItem] {
        installedApps.filter { app in
            if selectedFilter == .userApps && app.isSystemApp {
                return false
            }
            if searchQuery.isEmpty { return true }
            return app.name.localizedCaseInsensitiveContains(searchQuery) ||
                   app.bundleId.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private var filteredOrphans: [OrphanedRemnantGroup] {
        if searchQuery.isEmpty { return orphanedGroups }
        return orphanedGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.signature.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private var totalSelectedReclaimable: Int64 {
        if selectedFilter == .orphans {
            return orphanedGroups.filter { $0.isSelected }.reduce(0) { $0 + $1.totalSize }
        } else {
            return installedApps.reduce(0) { $0 + $1.selectedReclaimableSize }
        }
    }
    
    private var selectedAppsCount: Int {
        installedApps.filter { $0.isSelected }.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningIndicatorView
            } else if !hasScanned {
                idleHeroStageView
            } else {
                // Sonuçlar ve Üst Filtre Çubuğu
                topControlToolbar
                
                if let toast = statusToast {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(hex: "38BDF8"))
                            .font(.system(size: 12))
                        Text(toast)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { statusToast = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                // Ana Liste
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if selectedFilter == .orphans {
                            if filteredOrphans.isEmpty {
                                emptyOrphansView
                            } else {
                                ForEach(filteredOrphans) { group in
                                    OrphanGroupCard(
                                        group: group,
                                        onToggle: { toggleOrphanGroup(group.id) },
                                        onTrash: { trashSingleOrphan(group) }
                                    )
                                }
                            }
                        } else {
                            if filteredApps.isEmpty {
                                emptyAppsView
                            } else {
                                ForEach(filteredApps) { app in
                                    AppUninstallerRowCard(
                                        app: app,
                                        isExpanded: expandedAppIds.contains(app.id),
                                        onToggleExpand: { toggleExpand(app.id) },
                                        onToggleSelect: { toggleAppSelect(app.id) },
                                        onToggleRemnant: { remnantId in
                                            toggleRemnantSelect(appId: app.id, remnantId: remnantId)
                                        },
                                        onShowInFinder: { path in
                                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                
                // Alt Eylem ve Çöpe Taşıma Çubuğu
                bottomActionToolbar
            }
        }
        .alert(isPresented: $showConfirmDialog) {
            Alert(
                title: Text("Çöp Sepeti'ne Taşınsın mı?"),
                message: Text("Seçili \(selectedFilter == .orphans ? "\(filteredOrphans.filter{$0.isSelected}.count) yetim artık" : "\(selectedAppsCount) uygulama ve kalıntıları") macOS Çöp Sepeti'ne taşınacaktır. Bu işlem tamamen geri alınabilirdir."),
                primaryButton: .destructive(Text("Çöpe Taşı")) {
                    executeTrashOperation()
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // MARK: - 1. Hero Boşta Sahnesi
    private var idleHeroStageView: some View {
        HeroStageView(
            title: "Derin Uygulama Kaldırıcı",
            subtitle: "Uygulamaları ve tüm gizli sistem artıklarını kalıntı bırakmadan güvenle Çöp Sepeti'ne taşıyın.",
            emblemStyle: .crimson,
            emblemIcon: "xmark.bin.fill",
            bullets: [
                HeroStageView.BulletItem(
                    icon: "sparkles",
                    title: "Kalıntısız Tam Kaldırma",
                    description: "Application Support, Caches, Preferences ve Containers'a saçılan tüm izleri bulur."
                ),
                HeroStageView.BulletItem(
                    icon: "clock.arrow.circlepath",
                    title: "Yetim Kalıntı Radarı",
                    description: "Önceden elle silinmiş fakat diskte yer işgal eden sahipsiz kütüphane klasörlerini tespit eder."
                ),
                HeroStageView.BulletItem(
                    icon: "arrow.uturn.backward.circle.fill",
                    title: "%100 Geri Alınabilir Güvenlik",
                    description: "Asla kalıcı yok etmez; her şeyi macOS Çöp Sepeti'ne aktarır, dilediğinizde geri alabilirsiniz."
                )
            ],
            targetDiskInfo: " Macintosh HD (Mevcut Disk) · APFS",
            buttonTitle: "Uygulamaları Tara",
            buttonColorStyle: .dangerStop,
            isPulsing: true,
            onAction: {
                runScan()
            }
        )
    }
    
    // MARK: - 2. Tarama Aşaması
    private var scanningIndicatorView: some View {
        LuxuryScanningStageView(
            title: "Derin Sistem Kütüphaneleri Taranıyor...",
            subtitle: "Application Support • Caches • Containers • WebKit • Preferences",
            emblemStyle: .crimson,
            emblemIcon: "xmark.bin.fill",
            steps: ["1. Uygulama Paketleri", "2. Kütüphane Kırıntıları", "3. Yetim Artıklar"],
            currentStepIndex: 1,
            progressFraction: 0.7,
            currentItemName: "Uygulama kırıntıları ve yetim kütüphaneler tahlil ediliyor..."
        )
    }
    
    // MARK: - 3. Üst Kontrol Çubuğu
    private var topControlToolbar: some View {
        HStack(spacing: 12) {
            // Arama Kutusu
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.system(size: 12))
                
                TextField("Uygulama veya Kalıntı Ara...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .frame(minWidth: 140, maxWidth: 220)
            
            // Kategori Hapları
            HStack(spacing: 4) {
                ForEach(AppFilterType.allCases) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 10, weight: selectedFilter == filter ? .bold : .medium))
                            .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                selectedFilter == filter ?
                                    Color(hex: "EF4444").opacity(0.3) :
                                    Color.white.opacity(0.04)
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Yeniden Tara Butonu
            Button(action: runScan) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                    Text("Yenile")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - 4. Alt Eylem Çubuğu
    private var bottomActionToolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Geri Kazanılacak Alan:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalSelectedReclaimable, countStyle: .file))
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(hex: "34D399"))
                }
                
                Text("✓ Dosyalar kalıcı silinmez, macOS Çöp Sepeti'ne aktarılır (Geri Alınabilir).")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Button(action: {
                showConfirmDialog = true
            }) {
                HStack(spacing: 8) {
                    if isProcessingTrash {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Çöp Sepeti'ne Taşınıyor...")
                            .font(.system(size: 12, weight: .bold))
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12))
                        Text(selectedFilter == .orphans ? "Seçili Artıkları Çöpe Taşı" : "Seçilenleri Çöp Kutusuna Taşı")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "EF4444"), Color(hex: "B91C1C")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(hex: "EF4444").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(totalSelectedReclaimable == 0 || isProcessingTrash)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.3))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    private var emptyAppsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text("Arama kriterinize uygun uygulama bulunamadı.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
    
    private var emptyOrphansView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "10B981"))
            Text("Harika! Sisteminizde sahipsiz yetim kalıntı bulunmuyor.")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text("Daha önce silinen tüm uygulamaların arkasında bıraktığı kütüphaneler temiz.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }
    
    // MARK: - Eylemler
    private func runScan() {
        isScanning = true
        Task {
            let result = await AppUninstallerEngine.shared.scanInstalledApps()
            await MainActor.run {
                self.installedApps = result.apps
                self.orphanedGroups = result.orphans
                self.isScanning = false
                self.hasScanned = true
                SoundManager.shared.playSuccess()
                HapticManager.shared.triggerSuccess()
            }
        }
    }
    
    private func toggleExpand(_ id: String) {
        if expandedAppIds.contains(id) {
            expandedAppIds.remove(id)
        } else {
            expandedAppIds.insert(id)
        }
    }
    
    private func toggleAppSelect(_ id: String) {
        if let idx = installedApps.firstIndex(where: { $0.id == id }) {
            installedApps[idx].isSelected.toggle()
            let newState = installedApps[idx].isSelected
            // Remnant'ları da senkron seç
            for rIdx in installedApps[idx].remnants.indices {
                installedApps[idx].remnants[rIdx].isSelected = newState
            }
        }
    }
    
    private func toggleRemnantSelect(appId: String, remnantId: String) {
        if let aIdx = installedApps.firstIndex(where: { $0.id == appId }),
           let rIdx = installedApps[aIdx].remnants.firstIndex(where: { $0.id == remnantId }) {
            installedApps[aIdx].remnants[rIdx].isSelected.toggle()
        }
    }
    
    private func toggleOrphanGroup(_ id: String) {
        if let idx = orphanedGroups.firstIndex(where: { $0.id == id }) {
            orphanedGroups[idx].isSelected.toggle()
            let state = orphanedGroups[idx].isSelected
            for i in orphanedGroups[idx].items.indices {
                orphanedGroups[idx].items[i].isSelected = state
            }
        }
    }
    
    private func trashSingleOrphan(_ group: OrphanedRemnantGroup) {
        let res = AppUninstallerEngine.shared.trashOrphanGroup(group: group)
        if res.failedPaths.isEmpty {
            SoundManager.shared.playCardComplete()
            HapticManager.shared.triggerSuccess()
            orphanedGroups.removeAll(where: { $0.id == group.id })
            statusToast = "\(group.name) yetim kalıntıları Çöp Sepeti'ne taşındı."
        } else {
            SoundManager.shared.playError()
            HapticManager.shared.triggerWarning()
            statusToast = "Bazı kütüphane kırıntıları silinemedi (macOS yönetici izni verilmedi)."
        }
    }
    
    private func executeTrashOperation() {
        isProcessingTrash = true
        
        Task {
            var totalReclaimed: Int64 = 0
            var allFailedPaths: [String] = []
            
            if selectedFilter == .orphans {
                let toDelete = orphanedGroups.filter { $0.isSelected }
                for g in toDelete {
                    let res = AppUninstallerEngine.shared.trashOrphanGroup(group: g)
                    totalReclaimed += res.reclaimedSize
                    allFailedPaths.append(contentsOf: res.failedPaths)
                }
            } else {
                let appsToTrash = installedApps.filter { $0.isSelected || $0.remnants.contains(where: { $0.isSelected }) }
                for app in appsToTrash {
                    let res = AppUninstallerEngine.shared.trashApp(app: app, trashBundle: app.isSelected)
                    totalReclaimed += res.reclaimedSize
                    allFailedPaths.append(contentsOf: res.failedPaths)
                }
            }
            
            await MainActor.run {
                self.isProcessingTrash = false
                
                if allFailedPaths.isEmpty {
                    SoundManager.shared.playCleanFinished()
                    HapticManager.shared.triggerSuccess()
                    self.statusToast = "Seçilenler başarıyla Çöp Sepeti'ne taşındı (\(ByteCountFormatter.string(fromByteCount: totalReclaimed, countStyle: .file)) alan açıldı)."
                } else {
                    SoundManager.shared.playError()
                    HapticManager.shared.triggerWarning()
                    self.statusToast = "Bazı öğeler silinemedi (macOS yönetici izni verilmedi veya işlem iptal edildi)."
                }
                
                // Diskteki gerçek duruma göre listeyi yenile
                self.runScan()
            }
        }
    }
}

// MARK: - Uygulama Satır Kartı (Genişletilebilir Detay Çekmecesi)
struct AppUninstallerRowCard: View {
    let app: InstalledAppItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onToggleSelect: () -> Void
    let onToggleRemnant: (String) -> Void
    let onShowInFinder: (String) -> Void
    
    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: app.bundlePath)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana Satır
            HStack(spacing: 12) {
                // Seçim Kutusu
                if app.isSystemApp {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Color(hex: "F59E0B"))
                        .font(.system(size: 14))
                        .help("Sistem uygulamaları macOS tarafından korunur; sadece önbellek kırıntıları temizlenebilir.")
                } else {
                    Button(action: onToggleSelect) {
                        Image(systemName: app.isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(app.isSelected ? Color(hex: "EF4444") : .white.opacity(0.35))
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
                
                // Uygulama Simgesi
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)
                
                // Başlık & Bilgiler
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("v\(app.version)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(4)
                        
                        if app.isSystemApp {
                            Text("Sistem Korumalı")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(Color(hex: "F59E0B"))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: "F59E0B").opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(app.bundleId)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Kalıntı Sayısı & Boyut Özeti
                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("\(app.remnants.count + 1) Öğe • \(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file)) ikili")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Genişlet / Daralt Butonu
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            
            // Genişletilmiş Derin Kırıntı Listesi
            if isExpanded {
                VStack(spacing: 6) {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.horizontal, 12)
                    
                    // .app İkilisi Satırı
                    HStack(spacing: 8) {
                        Image(systemName: "app.dashed")
                            .foregroundColor(Color(hex: "38BDF8"))
                            .font(.system(size: 11))
                        
                        Text("Uygulama Paketi (.app)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                        
                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Button(action: { onShowInFinder(app.bundlePath) }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Finder'da Göster")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    
                    // Kütüphane Kırıntıları
                    ForEach(app.remnants) { remnant in
                        HStack(spacing: 8) {
                            Button(action: { onToggleRemnant(remnant.id) }) {
                                Image(systemName: remnant.isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundColor(remnant.isSelected ? Color(hex: "EF4444") : .white.opacity(0.3))
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(remnant.categoryName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Text(remnant.path)
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.35))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(remnant.formattedSize)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "34D399"))
                            
                            Button(action: { onShowInFinder(remnant.path) }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Finder'da Göster")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.2))
            }
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isExpanded ? Color(hex: "EF4444").opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Yetim Kalıntı Grubu Kartı
struct OrphanGroupCard: View {
    let group: OrphanedRemnantGroup
    let onToggle: () -> Void
    let onTrash: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: group.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(group.isSelected ? Color(hex: "EF4444") : .white.opacity(0.35))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                
                Image(systemName: "shippingbox.and.arrow.backward.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("\(group.items.count) Adet Kütüphane Klasörü")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Text(group.formattedSize)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "34D399"))
                
                Button(action: onTrash) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "FDA4AF"))
                        .padding(6)
                        .background(Color(hex: "EF4444").opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Bu yetim kalıntıyı Çöp Sepeti'ne taşı")
            }
            
            // Yollar
            VStack(alignment: .leading, spacing: 3) {
                ForEach(group.items) { item in
                    HStack {
                        Text(item.categoryName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(item.path)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(item.formattedSize)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
