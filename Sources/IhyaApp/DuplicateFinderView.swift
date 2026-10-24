import SwiftUI
import AppKit
import IhyaCore

public enum RetentionRule: String, CaseIterable, Identifiable {
    case keepOldest = "En Eski Dosyayı Koru (Önerilen)"
    case keepNewest = "En Yeni Dosyayı Koru"
    case keepDocuments = "Belgeleri Koru, İndirilenleri Sil"
    case trashDownloads = "İndirilenler Klasörünü Seç"
    case trashDesktop = "Masaüstü Klasörünü Seç"
    
    public var id: String { rawValue }
}

public struct DuplicateFinderView: View {
    @ObservedObject private var dupEngine = DuplicateFinderEngine.shared
    @State private var ignoredGroupIds: Set<String> = []
    
    // Filtreler & Sekmeler
    @State private var selectedFilter: FileCategoryType = .all
    @State private var isShowingFolderReport: Bool = false
    @State private var selectedFolderFilter: String? = nil
    @State private var isTargetedForDrop: Bool = false
    @State private var selectedFileForPreview: DuplicateFile? = nil
    @State private var activeRetentionRule: RetentionRule = .keepOldest
    
    public init() {}
    
    private var isScanning: Bool { dupEngine.isScanning }
    private var hasScanned: Bool { dupEngine.hasScanned }
    private var duplicateGroups: [DuplicateGroup] { dupEngine.duplicateGroups }
    
    // Aktif (Yoksayılmamış) Gruplar
    private var activeGroups: [DuplicateGroup] {
        dupEngine.duplicateGroups.filter { !ignoredGroupIds.contains($0.id) }
    }
    
    // Filtrelenmiş Gruplar
    private var filteredGroups: [DuplicateGroup] {
        var groups = activeGroups
        
        // Klasör filtresi
        if let folder = selectedFolderFilter {
            groups = groups.filter { group in
                group.files.contains { ($0.path as NSString).deletingLastPathComponent == folder }
            }
        }
        
        // Kategori filtresi
        if selectedFilter != .all {
            groups = groups.filter { group in
                guard let firstFile = group.files.first else { return false }
                return FileCategoryType.from(path: firstFile.path) == selectedFilter
            }
        }
        
        return groups
    }
    
    private var totalReclaimableFiltered: Int64 {
        filteredGroups.reduce(0) { $0 + $1.reclaimableSize }
    }
    
    private var folderSummaries: [FolderDuplicateSummary] {
        DuplicateFinderEngine.shared.getFolderSummaries(from: activeGroups)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isScanning {
                scanningIndicatorView
            } else if !hasScanned {
                idleHeroStageView
            } else if activeGroups.isEmpty {
                emptyResultView
            } else {
                // Sonuçlar ve Üst Yönetim Çubuğu
                resultsControlBar
                
                if isShowingFolderReport {
                    // Klasör Bazlı Rapor & Toplu İnceleme Sahnesi
                    folderReportStageView
                } else {
                    // İkiz Dosyalar ve Sağ Görsel Önizleme Bölünmüş Sahnesi
                    HStack(spacing: 0) {
                        // Sol: İkiz Dosya Grupları Listesi
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredGroups) { group in
                                    DuplicateGroupCard(
                                        group: group,
                                        selectedFileId: selectedFileForPreview?.id,
                                        onSelectFile: { file in
                                            selectedFileForPreview = file
                                        },
                                        onToggleFile: { fileId in
                                            toggleFileSelection(groupId: group.id, fileId: fileId)
                                        },
                                        onDeleteSingle: { filePath in
                                            trashFile(at: filePath)
                                        },
                                        onDismissGroup: {
                                            withAnimation(.spring()) {
                                                ignoredGroupIds.insert(group.id)
                                                HapticManager.shared.triggerClick()
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(16)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Sağ: Görsel Önizleme & Dosya Röntgen Çekmecesi (Side-by-Side Preview)
                        if let file = selectedFileForPreview ?? filteredGroups.first?.files.first {
                            VisualPreviewInspector(
                                file: file,
                                onToggleSelection: {
                                    toggleFileSelectionByPath(file.path)
                                },
                                onTrash: {
                                    trashFile(at: file.path)
                                }
                            )
                            .frame(width: 310)
                            .transition(.move(edge: .trailing))
                        }
                    }
                }
                
                // Alt Toplu Çöpe Taşıma Eylem Çubuğu
                bottomActionToolbar
            }
        }
        .onAppear {
            if dupEngine.scanTargets.isEmpty {
                dupEngine.scanTargets = DuplicateFinderEngine.defaultScanTargets()
            }
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isTargetedForDrop) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, url.hasDirectoryPath else { return }
                DispatchQueue.main.async {
                    self.addCustomFolderTarget(path: url.path)
                }
            }
            return true
        }
    }
    
    // MARK: - 1. Boşta / Hero Sahnesi (Çoklu Disk & Klasör Seçimi)
    private var idleHeroStageView: some View {
        GeometryReader { geo in
            let isCompactWidth = geo.size.width < 750
            let emblemSize: CGFloat = isCompactWidth ? 110 : 130
            
            VStack(spacing: 0) {
                Spacer(minLength: 16)
                
                HStack(alignment: .center, spacing: isCompactWidth ? 20 : 36) {
                    // Sol: 3D Mücevher Rozet
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "0284C7").opacity(0.35))
                                .frame(width: emblemSize * 1.5, height: emblemSize * 1.5)
                                .blur(radius: 36)
                            
                            GlassJewelEmblem(
                                style: .sapphire,
                                iconName: "doc.on.doc.fill",
                                size: emblemSize
                            )
                        }
                    }
                    .frame(width: isCompactWidth ? 130 : 160)
                    
                    // Sağ: Çoklu Disk Seçimi & Başlatma
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Çift Dosya Avcısı")
                                .font(.system(size: isCompactWidth ? 22 : 26, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("İsimleri farklı olsa dahi içeriği %100 aynı olan ikizleri POSIX SHA-256 motoruyla anında bulun.")
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Çoklu Taranacak Konumlar ve Harici Diskler
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("TARANACAK DİSKLER & KLASÖRLER:")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Spacer()
                                
                                Button(action: selectCustomFolder) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Özel Klasör Ekle")
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: "38BDF8"))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Çoklu Konum Seçici Çipleri
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(dupEngine.scanTargets.indices, id: \.self) { idx in
                                    let target = dupEngine.scanTargets[idx]
                                    Button(action: {
                                        dupEngine.scanTargets[idx].isSelected.toggle()
                                        HapticManager.shared.triggerClick()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: target.isSelected ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(target.isSelected ? Color(hex: "38BDF8") : .white.opacity(0.35))
                                                .font(.system(size: 12))
                                            
                                            Image(systemName: target.icon)
                                                .foregroundColor(target.isExternalDisk ? Color(hex: "F59E0B") : Color(hex: "38BDF8"))
                                                .font(.system(size: 11))
                                            
                                            Text(target.name)
                                                .font(.system(size: 11, weight: target.isSelected ? .bold : .medium))
                                                .foregroundColor(target.isSelected ? .white : .white.opacity(0.6))
                                                .lineLimit(1)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(target.isSelected ? Color(hex: "0284C7").opacity(0.25) : Color.white.opacity(0.04))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(target.isSelected ? Color(hex: "38BDF8").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                        
                        let selectedCount = dupEngine.scanTargets.filter { $0.isSelected }.count
                        FloatingActionButton(
                            title: selectedCount > 0 ? "Seçilen \(selectedCount) Konumda Çiftleri Ara" : "Lütfen En Az 1 Konum Seçin",
                            icon: "magnifyingglass",
                            shortcutHint: "⌘↩",
                            isPulsing: selectedCount > 0,
                            colorStyle: .sapphireBlue
                        ) {
                            if selectedCount > 0 {
                                runScan()
                            }
                        }
                        .disabled(selectedCount == 0)
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: 500)
                }
                .padding(.horizontal, 24)
                
                Spacer(minLength: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 2. Sonuçlar ve Yönetim Çubuğu
    private var resultsControlBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(Color(hex: "38BDF8"))
                        .font(.system(size: 13))
                    
                    Text("\(activeGroups.count) İkiz Grup Tespit Edildi")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let folder = selectedFolderFilter {
                        HStack(spacing: 4) {
                            Text("Filtre: \((folder as NSString).lastPathComponent)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "F59E0B"))
                            Button(action: { selectedFolderFilter = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "F59E0B").opacity(0.2))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Görünüm Değiştirici: İkizler vs Klasörler Raporu
                HStack(spacing: 0) {
                    Button(action: { isShowingFolderReport = false }) {
                        Text("İkiz Dosyalar")
                            .font(.system(size: 10, weight: !isShowingFolderReport ? .bold : .medium))
                            .foregroundColor(!isShowingFolderReport ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(!isShowingFolderReport ? Color(hex: "0284C7").opacity(0.4) : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { isShowingFolderReport = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.doc.horizontal")
                            Text("Klasörler Raporu (\(folderSummaries.count))")
                        }
                        .font(.system(size: 10, weight: isShowingFolderReport ? .bold : .medium))
                        .foregroundColor(isShowingFolderReport ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isShowingFolderReport ? Color(hex: "0284C7").opacity(0.4) : Color.clear)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                
                Text("|").foregroundColor(.white.opacity(0.2))
                
                // Akıllı Öncelik Kuralı Seçici Menü (Hangi Klasördekiler Korunsun)
                Menu {
                    Section("Akıllı Tarih Kuralları") {
                        Button("En Eski Dosyayı Koru (Orijinal)") {
                            applyDateRule(keepOldest: true)
                        }
                        Button("En Yeni Dosyayı Koru") {
                            applyDateRule(keepOldest: false)
                        }
                    }
                    
                    if !folderSummaries.isEmpty {
                        Section("Hangi Klasördekiler Korunsun?") {
                            ForEach(folderSummaries) { summary in
                                Button("👑 Sadece '\(summary.folderName)' Koru") {
                                    applyFolderRule(keepFolderPath: summary.folderPath)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        Text("Akıllı Kural Seç")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "38BDF8"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "0284C7").opacity(0.2))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "38BDF8").opacity(0.4), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                
                Text("|").foregroundColor(.white.opacity(0.2))
                
                // Seçim Düğmeleri
                Button("Tümünü Seç") {
                    selectAllDuplicates(true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "38BDF8"))
                
                Text("|").foregroundColor(.white.opacity(0.2))
                
                Button("Temizle") {
                    selectAllDuplicates(false)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Button(action: {
                    dupEngine.hasScanned = false
                    dupEngine.duplicateGroups = []
                    dupEngine.scanProgress = nil
                    HapticManager.shared.triggerClick()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Yeni Tarama Yap")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "38BDF8"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color(hex: "0284C7").opacity(0.18))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "38BDF8").opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Kategori Filtre Hapları
            HStack(spacing: 6) {
                ForEach(FileCategoryType.allCases, id: \.self) { cat in
                    Button(action: {
                        selectedFilter = cat
                        HapticManager.shared.triggerClick()
                    }) {
                        Text(cat.rawValue)
                            .font(.system(size: 10, weight: selectedFilter == cat ? .bold : .medium))
                            .foregroundColor(selectedFilter == cat ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedFilter == cat ? Color(hex: "0284C7").opacity(0.3) : Color.white.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedFilter == cat ? Color(hex: "38BDF8").opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
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
    
    // MARK: - 3. Klasör Bazlı Rapor Sahnesi
    private var folderReportStageView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Klasörlere Göre Çift Dosya Dağılımı")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Hangi klasörlerde çift kayıt biriktiğini inceleyin; tek tıkla o klasördeki kopyaları koruyun veya silin.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(folderSummaries) { summary in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(Color(hex: "38BDF8"))
                                    .font(.system(size: 16))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.folderName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(summary.folderPath)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Text("\(summary.count) Çift Dosya")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text(summary.formattedSize)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "34D399"))
                            }
                            
                            HStack(spacing: 8) {
                                Button("Bu Klasörü Koru") {
                                    applyFolderRule(keepFolderPath: summary.folderPath)
                                    isShowingFolderReport = false
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "10B981").opacity(0.2))
                                .foregroundColor(Color(hex: "34D399"))
                                .cornerRadius(5)
                                .buttonStyle(.plain)
                                
                                Button("Çiftleri Listele") {
                                    selectedFolderFilter = summary.folderPath
                                    isShowingFolderReport = false
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .foregroundColor(.white)
                                .cornerRadius(5)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - 4. Alt Eylem Çubuğu
    private var bottomActionToolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Geri Kazanılacak Alan:")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(ByteCountFormatter.string(fromByteCount: totalReclaimableFiltered, countStyle: .file))
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(hex: "34D399"))
                }
                
                Text("✓ Dosyalar doğrudan macOS Çöp Sepeti'ne aktarılır. İstediğiniz an geri alabilirsiniz.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.45))
            }
            
            Spacer()
            
            Button(action: trashSelectedDuplicates) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                    Text("Seçili Kopyaları Çöpe Taşı (\(ByteCountFormatter.string(fromByteCount: totalReclaimableFiltered, countStyle: .file)))")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "F43F5E"), Color(hex: "BE123C")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(hex: "F43F5E").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(totalReclaimableFiltered == 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.28))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    private var scanningIndicatorView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 1. Ana Dönen Halka & Aşama Başlığı
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 5)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(dupEngine.scanProgress?.progressFraction ?? 0.15))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "06B6D4"), Color(hex: "38BDF8"), Color(hex: "818CF8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: dupEngine.scanProgress?.progressFraction)
                    
                    Text("\(Int((dupEngine.scanProgress?.progressFraction ?? 0.05) * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Text(dupEngine.scanProgress?.step.title ?? "POSIX SHA-256 İle İkiz Dosyalar Aranıyor...")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            
            // 2. 3 Aşamalı Görsel Adım Çubuğu (Stepper)
            HStack(spacing: 10) {
                stepperStepPill(stepNumber: 1, title: "1. Boyut Süzgeci", currentStep: dupEngine.scanProgress?.step.rawValue ?? 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                stepperStepPill(stepNumber: 2, title: "2. 4KB Hızlı Hash", currentStep: dupEngine.scanProgress?.step.rawValue ?? 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.25))
                stepperStepPill(stepNumber: 3, title: "3. Paralel SHA-256", currentStep: dupEngine.scanProgress?.step.rawValue ?? 1)
            }
            
            // 3. İnce Yatay İlerleme Çubuğu (Progress Bar)
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "06B6D4"), Color(hex: "38BDF8"), Color(hex: "818CF8")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(14, geo.size.width * CGFloat(dupEngine.scanProgress?.progressFraction ?? 0.05)), height: 6)
                            .shadow(color: Color(hex: "38BDF8").opacity(0.5), radius: 6, x: 0, y: 0)
                            .animation(.linear(duration: 0.15), value: dupEngine.scanProgress?.progressFraction)
                    }
                }
                .frame(width: 440, height: 6)
            }
            
            // 4. Anlık Taranan Dosya Yolu Kapsülü (CleanMyMac Standardı)
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
                
                let path = dupEngine.scanProgress?.currentPath ?? "Dizinler taranıyor..."
                let displayPath = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                Text(displayPath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            // 5. Canlı Sayaçlar (Micro-Stats Pills)
            HStack(spacing: 12) {
                scanStatPill(
                    icon: "doc.text.magnifyingglass",
                    label: "İncelenen Dosya",
                    value: "\(dupEngine.scanProgress?.processedFiles ?? 0)"
                )
                scanStatPill(
                    icon: "bolt.badge.clock.fill",
                    label: "Aday Eşleşme",
                    value: "\(dupEngine.scanProgress?.totalCandidates ?? 0)"
                )
                scanStatPill(
                    icon: "doc.on.doc.fill",
                    label: "Bulunan İkiz Grup",
                    value: "\(dupEngine.scanProgress?.foundDuplicateGroups ?? 0)"
                )
            }
            
            // 6. Taramayı Durdur Düğmesi (User Control)
            Button(action: {
                HapticManager.shared.triggerClick()
                dupEngine.cancelScan()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 13))
                    Text("Taramayı Durdur")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundColor(Color(hex: "F87171"))
                .background(Color(hex: "EF4444").opacity(0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "EF4444").opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func stepperStepPill(stepNumber: Int, title: String, currentStep: Int) -> some View {
        let isDone = currentStep > stepNumber
        let isActive = currentStep == stepNumber
        
        return HStack(spacing: 6) {
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "10B981"))
                    .font(.system(size: 11, weight: .bold))
            } else if isActive {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
            
            Text(title)
                .font(.system(size: 11, weight: isActive ? .bold : .medium))
                .foregroundColor(isDone ? Color(hex: "10B981") : (isActive ? Color(hex: "38BDF8") : .white.opacity(0.45)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color(hex: "38BDF8").opacity(0.12) : Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color(hex: "38BDF8").opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func scanStatPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "38BDF8"))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "10B981"))
            
            Text("Harika! Seçilen Konumlarda Çift Dosya Yok.")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Tüm dosyalar benzersiz ve optimize edilmiş durumda.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            Button("Farklı Klasörleri Tara") {
                dupEngine.hasScanned = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
    }
    
    // MARK: - Eylemler & Mantık
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                addCustomFolderTarget(path: url.path)
            }
        }
    }
    
    private func addCustomFolderTarget(path: String) {
        if !dupEngine.scanTargets.contains(where: { $0.path == path }) {
            dupEngine.scanTargets.append(ScanTargetItem(
                name: (path as NSString).lastPathComponent,
                path: path,
                icon: "folder.badge.plus",
                isSelected: true
            ))
        }
    }
    
    private func runScan() {
        let selectedPaths = dupEngine.scanTargets.filter { $0.isSelected }.map { $0.path }
        guard !selectedPaths.isEmpty else { return }
        
        ignoredGroupIds.removeAll()
        dupEngine.startBackgroundScan(targets: selectedPaths) {
            Task { @MainActor in
                SoundManager.shared.playSuccess()
                HapticManager.shared.triggerSuccess()
            }
        }
    }
    
    private func toggleFileSelection(groupId: String, fileId: String) {
        if let gIndex = dupEngine.duplicateGroups.firstIndex(where: { $0.id == groupId }),
           let fIndex = dupEngine.duplicateGroups[gIndex].files.firstIndex(where: { $0.id == fileId }) {
            dupEngine.duplicateGroups[gIndex].files[fIndex].isSelectedForDeletion.toggle()
        }
    }
    
    private func toggleFileSelectionByPath(_ path: String) {
        for gIndex in dupEngine.duplicateGroups.indices {
            for fIndex in dupEngine.duplicateGroups[gIndex].files.indices {
                if dupEngine.duplicateGroups[gIndex].files[fIndex].path == path {
                    dupEngine.duplicateGroups[gIndex].files[fIndex].isSelectedForDeletion.toggle()
                    return
                }
            }
        }
    }
    
    private func selectAllDuplicates(_ select: Bool) {
        for gIndex in dupEngine.duplicateGroups.indices {
            for fIndex in dupEngine.duplicateGroups[gIndex].files.indices {
                if !dupEngine.duplicateGroups[gIndex].files[fIndex].isOriginal {
                    dupEngine.duplicateGroups[gIndex].files[fIndex].isSelectedForDeletion = select
                }
            }
        }
    }
    
    private func applyFolderRule(keepFolderPath: String) {
        dupEngine.duplicateGroups = DuplicateFinderEngine.shared.applyFolderRetentionRule(
            groups: dupEngine.duplicateGroups,
            keepFolderPath: keepFolderPath
        )
        HapticManager.shared.triggerSuccess()
    }
    
    private func applyDateRule(keepOldest: Bool) {
        dupEngine.duplicateGroups = DuplicateFinderEngine.shared.applyDateRetentionRule(
            groups: dupEngine.duplicateGroups,
            keepOldest: keepOldest
        )
        HapticManager.shared.triggerSuccess()
    }
    
    private func trashFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        SoundManager.shared.playCardComplete()
        HapticManager.shared.triggerSuccess()
        runScan()
    }
    
    private func trashSelectedDuplicates() {
        var filesToTrash: [String] = []
        for group in activeGroups {
            for file in group.files where file.isSelectedForDeletion && !file.isOriginal {
                filesToTrash.append(file.path)
            }
        }
        
        for path in filesToTrash {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        
        SoundManager.shared.playCleanFinished()
        HapticManager.shared.triggerSuccess()
        runScan()
    }
}

// MARK: - İkiz Grup Kartı (Modüler)
struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    let selectedFileId: String?
    let onSelectFile: (DuplicateFile) -> Void
    let onToggleFile: (String) -> Void
    let onDeleteSingle: (String) -> Void
    let onDismissGroup: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundColor(Color(hex: "38BDF8"))
                    .font(.system(size: 13))
                
                Text("İkiz Grup • \(group.formattedSize) / dosya")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                // İsimleri Farklı Ama İçeriği Aynı Rozeti!
                if group.isDifferentNames {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text("İsimleri Farklı • Bire Bir Aynı Kopya")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "FBBF24"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "F59E0B").opacity(0.18))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                Text("\(group.files.count) Adet")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                // "Eş Değil / Yoksay" Düğmesi
                Button(action: onDismissGroup) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle")
                        Text("Eş Değil / Yoksay")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Bu dosyalar eş değilse listeden kaldırır")
            }
            
            ForEach(group.files) { file in
                DuplicateFileRow(
                    file: file,
                    isSelectedInInspector: selectedFileId == file.id,
                    onClickRow: { onSelectFile(file) },
                    onToggle: { onToggleFile(file.id) },
                    onDelete: { onDeleteSingle(file.path) }
                )
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - İkiz Dosya Satırı
struct DuplicateFileRow: View {
    let file: DuplicateFile
    let isSelectedInInspector: Bool
    let onClickRow: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            if file.isOriginal {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color(hex: "10B981"))
                    .font(.system(size: 14))
            } else {
                Button(action: onToggle) {
                    Image(systemName: file.isSelectedForDeletion ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(file.isSelectedForDeletion ? Color(hex: "F43F5E") : .white.opacity(0.4))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(file.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                    
                    if file.isOriginal {
                        Text("Orijinal")
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "10B981").opacity(0.2))
                            .foregroundColor(Color(hex: "34D399"))
                            .cornerRadius(3)
                    }
                }
                
                Text(file.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(file.formattedDate)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.4))
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .help("Doğrudan Çöp Sepeti'ne Taşı")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelectedInInspector ? Color(hex: "0284C7").opacity(0.2) : Color.white.opacity(0.02))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            onClickRow()
        }
    }
}

// MARK: - Görsel Önizleme & Dosya Röntgen Çekmecesi (Side-by-Side Visual Preview)
struct VisualPreviewInspector: View {
    let file: DuplicateFile
    let onToggleSelection: () -> Void
    let onTrash: () -> Void
    
    private var isImageFile: Bool {
        let ext = (file.path as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "webp", "gif", "tiff", "bmp"].contains(ext)
    }
    
    private var previewImage: NSImage? {
        guard isImageFile else { return nil }
        return NSImage(contentsOfFile: file.path)
    }
    
    private var imageDimensions: String {
        guard let img = previewImage else { return "" }
        if let rep = img.representations.first {
            return "\(rep.pixelsWide) × \(rep.pixelsHigh) piksel"
        }
        return "\(Int(img.size.width)) × \(Int(img.size.height)) pt"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Başlık
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(Color(hex: "38BDF8"))
                    .font(.system(size: 12))
                Text("Görsel İnceleme & Röntgen")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            
            // Görsel Önizleme Alanı
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.3))
                
                if let img = previewImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                        
                        Text((file.path as NSString).pathExtension.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(height: 140)
                }
            }
            .padding(.horizontal, 14)
            
            // Boyut ve Çözünürlük Hapı
            if !imageDimensions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9))
                    Text(imageDimensions)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(Color(hex: "38BDF8"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "0284C7").opacity(0.2))
                .cornerRadius(5)
            }
            
            // Detaylı Bilgi Listesi
            VStack(alignment: .leading, spacing: 6) {
                detailRow(label: "Dosya Adı", value: file.name)
                detailRow(label: "Durum", value: file.isOriginal ? "Orijinal Nüsha" : "Kopya")
                detailRow(label: "Değiştirilme", value: file.formattedDate)
                detailRow(label: "Konum", value: file.path)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            
            // Hızlı Eylem Düğmeleri
            HStack(spacing: 8) {
                // Quick Look Aç
                Button(action: {
                    let url = URL(fileURLWithPath: file.path)
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Aç / Önizle")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // Finder'da Göster
                Button(action: {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                        Text("Finder'da")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            
            Spacer()
        }
        .background(Color.black.opacity(0.25))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1),
            alignment: .leading
        )
    }
    
    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
            
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
        }
    }
}
