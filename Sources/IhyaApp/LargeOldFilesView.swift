import SwiftUI
import AppKit
import QuickLookThumbnailing
import IhyaCore

// MARK: - Gerçek Video ve Görsel Küçük Resim Üreteci (QLThumbnailGenerator)
public struct LargeFileThumbnailView: View {
    let path: String
    @State private var thumbnail: NSImage? = nil
    
    public init(path: String) {
        self.path = path
    }
    
    public var body: some View {
        ZStack {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            }
        }
        .task(id: path) {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let ext = (path as NSString).pathExtension.lowercased()
        let visualExtensions: Set<String> = ["mov", "mp4", "m4v", "mkv", "avi", "png", "jpg", "jpeg", "webp", "heic", "tiff", "pdf"]
        guard visualExtensions.contains(ext) else { return }
        
        let url = URL(fileURLWithPath: path)
        let size = CGSize(width: 72, height: 72)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let req = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        
        Task {
            do {
                let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: req)
                await MainActor.run {
                    self.thumbnail = rep.nsImage
                }
            } catch {
                // Ön izleme üretilemezse varsayılan ikon kalır
            }
        }
    }
}

public struct LargeOldFilesView: View {
    @StateObject private var engine = LargeOldFilesEngine.shared
    @State private var showDeleteConfirm: Bool = false
    @State private var showShredConfirm: Bool = false
    @State private var showOffloadSheet: Bool = false
    @State private var selectedDiskForOffload: ExternalStorageDisk? = nil
    @State private var itemToShred: LargeOldFileItem? = nil
    @State private var focusedItemId: String? = nil
    @State private var isProcessing: Bool = false
    @State private var resultMessage: String = ""
    @State private var showResultToast: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Sabit Üst Başlık & Kontrol Çubuğu
            headerBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // MARK: - 2. Duruma Göre Sahne
            if engine.isScanning {
                scanningStage
            } else if !engine.hasScanned {
                idleHeroStage
            } else if engine.items.isEmpty {
                emptyResultStage
            } else {
                // Filtreler & Dosya Listesi
                VStack(spacing: 0) {
                    filterAndSearchSection
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.15))
                    
                    Divider()
                        .background(Color.white.opacity(0.06))
                    
                    // Akıllı Harici Disk Arşivleme Öneri Bandı
                    if !engine.availableExternalDisks.isEmpty {
                        externalDiskSmartBanner
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                    }
                    
                    // Dosya Kartları Listesi
                    filesListScrollSection
                    
                    // Alt Sabit Eylem Çubuğu
                    bottomStickyBar
                }
            }
        }
        .onAppear {
            if !engine.hasScanned && !engine.isScanning {
                Task {
                    await engine.scan()
                }
            } else {
                engine.refreshExternalDisks()
            }
            if selectedDiskForOffload == nil {
                selectedDiskForOffload = engine.availableExternalDisks.first
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Seçili \(engine.selectedCount) Dosya Çöp Sepeti'ne Taşınsın mı?"),
                message: Text("Toplam \(ByteCountFormatter.string(fromByteCount: engine.selectedReclaimableBytes, countStyle: .file)) alan geri kazanılacaktır. Bu işlem macOS Çöp Sepeti üzerinden tamamen geri alınabilirdir."),
                primaryButton: .destructive(Text("Çöp Sepeti'ne Taşı")) {
                    executeTrashAction()
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
        .sheet(isPresented: $showShredConfirm) {
            shredConfirmationSheet
        }
        .sheet(isPresented: $showOffloadSheet) {
            offloadConfirmationSheet
        }
        .overlay(
            toastOverlay
        )
        // Space Tuşu ile Seçili / Odaklı Dosyayı Anında Önizle (Kâşif & Finder Standartı)
        .background(
            Button("") {
                handleSpaceQuickLook()
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
        )
    }
    
    // MARK: - Space Tuşu ile Hızlı Önizleme
    private func handleSpaceQuickLook() {
        if let focusedId = focusedItemId, let item = engine.filteredItems.first(where: { $0.id == focusedId }) {
            QuickLookHelper.shared.preview(path: item.path)
        } else if let selected = engine.filteredItems.first(where: { $0.isSelected }) {
            QuickLookHelper.shared.preview(path: selected.path)
        } else if let first = engine.filteredItems.first {
            QuickLookHelper.shared.preview(path: first.path)
        }
    }
    
    // MARK: - Üst Başlık & Sağ Eylem Çubuğu
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Büyük & Eski Dosyalar Radarı")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if engine.hasScanned {
                        Text("\(engine.filteredItems.count) Dosya")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "F59E0B").opacity(0.2))
                            .foregroundColor(Color(hex: "FBBF24"))
                            .clipShape(Capsule())
                    }
                }
                
                Text("Aylardır dokunulmamış 100 MB+ devasa arşivleri, disk kalıplarını ve medyaları arındırın.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Tara / Yeniden Tara Butonu
            Button(action: {
                Task {
                    await engine.scan()
                    SoundManager.shared.playSuccessChime()
                    HapticManager.shared.generateSuccessFeedback()
                }
            }) {
                HStack(spacing: 6) {
                    if engine.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(engine.hasScanned ? "Yeniden Tara" : "Taramayı Başlat")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(engine.isScanning)
        }
    }
    
    // MARK: - Akıllı Harici Disk Arşivleme Öneri Bandı
    private var externalDiskSmartBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "38BDF8"))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Harici Disk Bağlı:")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let firstDisk = engine.availableExternalDisks.first {
                        Text("\(firstDisk.name) (\(firstDisk.formattedFreeSpace) Boş Alan)")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "38BDF8"))
                    }
                }
                
                Text("Büyük videoları veya arşivleri silmek istemiyorsanız; doğrudan harici diske taşıyarak Mac SSD'nizde güvenle yer açabilirsiniz.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            if engine.selectedCount > 0 {
                Button(action: {
                    showOffloadSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Harici Diske Arşivle (\(ByteCountFormatter.string(fromByteCount: engine.selectedReclaimableBytes, countStyle: .file)))")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "0284C7"))
                    .foregroundColor(.white)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(hex: "0369A1").opacity(0.15))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(hex: "38BDF8").opacity(0.25), lineWidth: 1)
        )
    }
    
    // MARK: - Filtre & Arama Bölümü
    private var filterAndSearchSection: some View {
        VStack(spacing: 10) {
            // Üst Satır: Arama & Hızlı Seçim Kısayolları
            HStack(spacing: 12) {
                // Arama Kutusu
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField("Dosya adı veya klasörde filtrele...", text: $engine.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    
                    if !engine.searchQuery.isEmpty {
                        Button(action: { engine.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(maxWidth: 320)
                
                Spacer()
                
                // Akıllı Seçim Kısayolları
                HStack(spacing: 6) {
                    shortcutPill(title: "1 Yıldan Eskiler", icon: "clock.arrow.circlepath") {
                        engine.selectOlderThanYear()
                        HapticManager.shared.triggerClick()
                    }
                    shortcutPill(title: "5 GB Üzeri", icon: "scalemass.fill") {
                        engine.selectAbove5GB()
                        HapticManager.shared.triggerClick()
                    }
                    shortcutPill(title: "Tümünü Seç", icon: "checkmark.circle") {
                        engine.selectAllFiltered()
                        HapticManager.shared.triggerClick()
                    }
                    shortcutPill(title: "Temizle", icon: "circle") {
                        engine.deselectAll()
                        HapticManager.shared.triggerClick()
                    }
                }
            }
            
            // Alt Satır: Kategori, Boyut ve Zaman Filtre Hapları
            HStack(spacing: 12) {
                // Tür Filtresi
                Menu {
                    ForEach(LargeFileCategory.allCases) { cat in
                        Button(action: { engine.selectedCategory = cat }) {
                            HStack {
                                Text(cat.rawValue)
                                if engine.selectedCategory == cat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    filterDropdownLabel(
                        title: engine.selectedCategory.rawValue,
                        icon: engine.selectedCategory.icon,
                        isActive: engine.selectedCategory != .all
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                // Boyut Filtresi
                Menu {
                    ForEach(LargeFileSizeGroup.allCases) { sizeGroup in
                        Button(action: { engine.selectedSizeGroup = sizeGroup }) {
                            HStack {
                                Text(sizeGroup.rawValue)
                                if engine.selectedSizeGroup == sizeGroup {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    filterDropdownLabel(
                        title: engine.selectedSizeGroup.rawValue,
                        icon: "gauge.with.dots.needle.50percent",
                        isActive: engine.selectedSizeGroup != .all
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                // Zaman Filtresi
                Menu {
                    ForEach(LargeFileTimeGroup.allCases) { timeGroup in
                        Button(action: { engine.selectedTimeGroup = timeGroup }) {
                            HStack {
                                Text(timeGroup.rawValue)
                                if engine.selectedTimeGroup == timeGroup {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    filterDropdownLabel(
                        title: engine.selectedTimeGroup.rawValue,
                        icon: "clock.fill",
                        isActive: engine.selectedTimeGroup != .all
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Spacer()
                
                // Toplam Filtrelenmiş Hacim Bilgisi
                Text("Toplam: \(ByteCountFormatter.string(fromByteCount: engine.totalReclaimableBytes, countStyle: .file))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
    }
    
    private func filterDropdownLabel(title: String, icon: String, isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color(hex: "F59E0B").opacity(0.18) : Color.white.opacity(0.04))
        .foregroundColor(isActive ? Color(hex: "FBBF24") : .white.opacity(0.8))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color(hex: "F59E0B").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func shortcutPill(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .foregroundColor(.white.opacity(0.75))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Dosya Kartları Listesi
    private var filesListScrollSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(engine.filteredItems) { item in
                    fileRowCard(item)
                }
            }
            .padding(24)
        }
    }
    
    private func fileRowCard(_ item: LargeOldFileItem) -> some View {
        let isFocused = focusedItemId == item.id
        
        return HStack(spacing: 12) {
            // Seçim Kutusu
            Button(action: {
                engine.toggleSelection(for: item.id)
                focusedItemId = item.id
                HapticManager.shared.triggerClick()
            }) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSelected ? Color(hex: "F59E0B") : Color.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            
            // Gerçek Video / Görsel Küçük Resmi (Thumbnail)
            LargeFileThumbnailView(path: item.path)
                .frame(width: 36, height: 36)
                .onTapGesture(count: 2) {
                    QuickLookHelper.shared.preview(path: item.path)
                }
            
            // Dosya Adı ve Yolu
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // Zaman Rozeti
                    timeBadgeView(item.timeGroup, text: item.relativeAccessTimeText)
                }
                
                Text(item.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedItemId = item.id
            }
            
            Spacer()
            
            // Boyut Etiketi
            Text(item.formattedSize)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(item.size >= 5 * 1024 * 1024 * 1024 ? Color(hex: "EF4444") : Color(hex: "FBBF24"))
                .frame(minWidth: 80, alignment: .trailing)
            
            // Eylem Düğmeleri
            HStack(spacing: 8) {
                // Space Önizleme (QuickLook) - Apple Native QLPreviewPanel (Asla çökmez!)
                Button(action: {
                    focusedItemId = item.id
                    QuickLookHelper.shared.preview(path: item.path)
                }) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Dosyayı Önizle (Space)")
                
                // Finder'da Göster
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                }) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Finder'da Göster")
                
                // Askeri Seviye Kalıcı Öğüt (Shred)
                Button(action: {
                    itemToShred = item
                    showShredConfirm = true
                }) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "EF4444").opacity(0.8))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "EF4444").opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Kalıcı Olarak Öğüt (Geri Getirilemez)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            item.isSelected
                ? Color(hex: "F59E0B").opacity(0.08)
                : (isFocused ? Color.white.opacity(0.05) : Color.white.opacity(0.03))
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    item.isSelected
                        ? Color(hex: "F59E0B").opacity(0.3)
                        : (isFocused ? Color.white.opacity(0.2) : Color.white.opacity(0.06)),
                    lineWidth: 1
                )
        )
    }
    
    private func timeBadgeView(_ group: LargeFileTimeGroup, text: String) -> some View {
        let color: Color
        switch group {
        case .olderThanYear: color = Color(hex: "EF4444")
        case .olderThanSixMonths: color = Color(hex: "F59E0B")
        case .olderThanMonth: color = Color(hex: "38BDF8")
        case .recent, .all: color = Color.white.opacity(0.4)
        }
        
        return Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
    
    // MARK: - Alt Sabit Eylem Çubuğu
    private var bottomStickyBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 16) {
                // Seçim Özeti
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "F59E0B"))
                    
                    Text("\(engine.selectedCount) Dosya Seçildi")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Hacim: \(ByteCountFormatter.string(fromByteCount: engine.selectedReclaimableBytes, countStyle: .file))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "FBBF24"))
                }
                
                Spacer()
                
                // 1. Harici Diske Taşı (Akıllı Arşivleme) Butonu
                if !engine.availableExternalDisks.isEmpty {
                    Button(action: {
                        showOffloadSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.badge.plus")
                                .font(.system(size: 12))
                            Text("Harici Diske Taşı")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(engine.selectedCount > 0 ? Color(hex: "0284C7") : Color.white.opacity(0.08))
                        .foregroundColor(engine.selectedCount > 0 ? Color.white : Color.white.opacity(0.3))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.selectedCount == 0 || isProcessing || engine.isOffloading)
                    .help("Seçili dosyaları harici diske güvenle arşivler ve Mac diskinizde yer açar")
                }
                
                // 2. Çöp Sepetine Taşı Eylemi
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12))
                        Text("Çöp Sepeti'ne Taşı (\(ByteCountFormatter.string(fromByteCount: engine.selectedReclaimableBytes, countStyle: .file)))")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(engine.selectedCount > 0 ? Color(hex: "F59E0B") : Color.white.opacity(0.1))
                    .foregroundColor(engine.selectedCount > 0 ? Color.black : Color.white.opacity(0.3))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(engine.selectedCount == 0 || isProcessing || engine.isOffloading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.4))
        }
    }
    
    // MARK: - Harici Diske Güvenli Arşivleme / Taşıma Sayfası (Sheet)
    private var offloadConfirmationSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "38BDF8"))
            
            VStack(spacing: 5) {
                Text("Harici Diske Güvenli Arşivleme")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Seçili büyük dosyalar harici diske kopyalanıp bütünlüğü (boyut kontrolü) doğrulandıktan sonra Mac SSD'nizden silinecek ve diskinizde anında yer açılacaktır.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Hedef Disk Seçici
            VStack(alignment: .leading, spacing: 6) {
                Text("HEDEF HARİCİ DİSK:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                
                ForEach(engine.availableExternalDisks) { disk in
                    let isSelected = selectedDiskForOffload?.id == disk.id
                    Button(action: {
                        selectedDiskForOffload = disk
                        HapticManager.shared.triggerClick()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
                                .foregroundColor(isSelected ? Color(hex: "38BDF8") : .white.opacity(0.3))
                            
                            Image(systemName: "externaldrive.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "38BDF8"))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(disk.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Boş Alan: \(disk.formattedFreeSpace) / \(disk.formattedTotalSpace)")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding(10)
                        .background(isSelected ? Color(hex: "38BDF8").opacity(0.12) : Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color(hex: "38BDF8").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Taşınacak Özet
            HStack {
                Text("Taşınacak Dosya Sayısı:")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(engine.selectedCount) Dosya (\(ByteCountFormatter.string(fromByteCount: engine.selectedReclaimableBytes, countStyle: .file)))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "FBBF24"))
            }
            .padding(.horizontal, 4)
            
            // Eğer taşıma yapılıyorsa ilerleme çubuğu
            if engine.isOffloading {
                VStack(spacing: 6) {
                    ProgressView(value: engine.offloadProgressFraction)
                        .accentColor(Color(hex: "38BDF8"))
                    
                    Text(engine.offloadProgressText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "38BDF8"))
                }
                .padding(.top, 4)
            }
            
            // Düğmeler
            HStack(spacing: 12) {
                Button("Vazgeç") {
                    showOffloadSheet = false
                }
                .buttonStyle(.bordered)
                .disabled(engine.isOffloading)
                
                Button(action: {
                    if let targetDisk = selectedDiskForOffload ?? engine.availableExternalDisks.first {
                        executeOffloadAction(to: targetDisk)
                    }
                }) {
                    HStack(spacing: 6) {
                        if engine.isOffloading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(engine.isOffloading ? "Taşınıyor..." : "Taşımayı Başlat (Mac'te Yer Aç)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "0284C7"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(engine.isOffloading || engine.selectedCount == 0)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(hex: "0C1A2E"))
    }
    
    // MARK: - Taramada Aşaması (LuxuryScanningStageView)
    private var scanningStage: some View {
        LuxuryScanningStageView(
            title: "Büyük ve Eski Dosyalar Taranıyor",
            subtitle: "Mac'inizdeki 100 MB üzeri unutulmuş dosyalar, arşivler ve disk kalıpları analiz ediliyor...",
            emblemStyle: .amber,
            emblemIcon: "archivebox.fill",
            steps: ["1. Depolama Haritası", "2. Erişim Zamanları", "3. Boyut İndeksi"],
            currentStepIndex: engine.scanProgress < 0.4 ? 1 : (engine.scanProgress < 0.8 ? 2 : 3),
            progressFraction: engine.scanProgress,
            currentItemName: engine.currentScanningPath,
            onCancel: {
                engine.cancelScan()
            }
        )
    }
    
    // MARK: - Boş Durum Sahnesi
    private var idleHeroStage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            GlassJewelEmblem(
                style: .amber,
                iconName: "archivebox.fill",
                size: 72
            )
            
            VStack(spacing: 6) {
                Text("Büyük & Eski Dosyalar Radarı")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Mac'inizde yer kaplayan ama aylardır açmadığınız 100 MB, 1 GB ve 5 GB üzeri\ndevasa dosyaları tek tıkla tespit edin.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task {
                    await engine.scan()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("Dev Dosyaları Tara")
                }
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "F59E0B"))
                .foregroundColor(.black)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    // MARK: - Sonuç Bulunamadı (Sistem Tertemiz)
    private var emptyResultStage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            GlassJewelEmblem(
                style: .emerald,
                iconName: "checkmark.seal.fill",
                size: 64
            )
            
            VStack(spacing: 5) {
                Text("Devasa Dosya Tespit Edilmedi")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Mac'inizde 100 MB üzerinde yer kaplayan unutulmuş veya eski bir dosya bulunmuyor. Depolamanız gayet düzenli.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Kalıcı Öğütme Onay Sayfası
    private var shredConfirmationSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "EF4444"))
            
            VStack(spacing: 6) {
                Text("Askeri Standartta Dosya Öğütme")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Bu dosyanın disk blokları sıfırlar ve rastgele baytlarla ezilecek; hiçbir veri kurtarma yazılımı ile geri getirilemeyecektir.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            if let item = itemToShred {
                VStack(spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(item.formattedSize)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "FBBF24"))
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            
            HStack(spacing: 12) {
                Button("Vazgeç") {
                    showShredConfirm = false
                    itemToShred = nil
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    if let item = itemToShred {
                        executeShredAction(item: item)
                    }
                    showShredConfirm = false
                }) {
                    Text("Kalıcı Olarak Öğüt ve Yok Et")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "EF4444"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(width: 440)
        .background(Color(hex: "180C14"))
    }
    
    // MARK: - Eylemler
    private func executeTrashAction() {
        isProcessing = true
        Task {
            let res = await engine.trashSelected()
            isProcessing = false
            SoundManager.shared.playSuccessChime()
            HapticManager.shared.generateSuccessFeedback()
            
            resultMessage = "\(res.successCount) dosya Çöp Sepeti'ne taşındı (\(ByteCountFormatter.string(fromByteCount: res.freedBytes, countStyle: .file)) geri kazanıldı)"
            withAnimation {
                showResultToast = true
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation {
                showResultToast = false
            }
        }
    }
    
    private func executeOffloadAction(to disk: ExternalStorageDisk) {
        Task {
            let res = await engine.offloadSelectedFiles(to: disk)
            showOffloadSheet = false
            
            if let err = res.errorText {
                resultMessage = "Hata: \(err)"
            } else {
                SoundManager.shared.playSuccessChime()
                HapticManager.shared.generateSuccessFeedback()
                resultMessage = "\(res.successCount) dosya '\(disk.name)' diskine arşivlendi (\(ByteCountFormatter.string(fromByteCount: res.movedBytes, countStyle: .file)) Mac'te yer açıldı!)"
            }
            
            withAnimation {
                showResultToast = true
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation {
                showResultToast = false
            }
        }
    }
    
    private func executeShredAction(item: LargeOldFileItem) {
        do {
            try engine.shredFile(at: item.path)
            SoundManager.shared.playSuccessChime()
            HapticManager.shared.generateSuccessFeedback()
            resultMessage = "\(item.name) kalıcı olarak öğütüldü ve diskten silindi."
            withAnimation {
                showResultToast = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation {
                    showResultToast = false
                }
            }
        } catch {
            resultMessage = "Hata: Dosya öğütülemedi (\(error.localizedDescription))"
            withAnimation {
                showResultToast = true
            }
        }
    }
    
    private var toastOverlay: some View {
        VStack {
            Spacer()
            if showResultToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "10B981"))
                    Text(resultMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
                .cornerRadius(20)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(radius: 10)
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
