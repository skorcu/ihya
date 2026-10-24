import SwiftUI
import AppKit
import IhyaCore

public enum StartupCategoryFilter: String, CaseIterable, Identifiable {
    case all = "Tümü"
    case loginItems = "Giriş Uygulamaları"
    case launchAgents = "Arka Plan Servisleri"
    case broken = "Kırık / Ölü Kayıtlar"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "list.bullet.rectangle"
        case .loginItems: return "play.rectangle.fill"
        case .launchAgents: return "gearshape.2.fill"
        case .broken: return "exclamationmark.triangle.fill"
        }
    }
}

public struct StartupManagerView: View {
    @StateObject private var engine = StartupItemsEngine.shared
    @State private var selectedFilter: StartupCategoryFilter = .all
    @State private var searchText: String = ""
    @State private var itemToDelete: StartupItem? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var isCleaningBroken: Bool = false
    
    public init() {}
    
    private var filteredItems: [StartupItem] {
        engine.items.filter { item in
            // Kategori Filtresi
            let matchesCategory: Bool
            switch selectedFilter {
            case .all:
                matchesCategory = true
            case .loginItems:
                matchesCategory = item.type == .loginItem
            case .launchAgents:
                matchesCategory = item.type == .launchAgent || item.type == .launchDaemon
            case .broken:
                matchesCategory = item.isBroken
            }
            guard matchesCategory else { return false }
            
            // Arama Filtresi
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return item.name.lowercased().contains(query) ||
                   item.vendor.lowercased().contains(query) ||
                   item.path.lowercased().contains(query)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Üst Başlık & Eylem Çubuğu
            headerBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // MARK: - 2. İstatistik & Filtre Kontrolleri
            filterAndSearchBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            
            // MARK: - 3. Başlangıç Öğeleri Listesi
            if engine.isLoading {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color(hex: "8B5CF6"))
                    Text("Mac başlangıç ve arka plan servisleri taranıyor...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            startupItemRow(item: item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .task {
            if engine.items.isEmpty {
                await engine.scanAllItems()
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("\(itemToDelete?.name ?? "Servis") Kaldırılsın mı?"),
                message: Text("Bu başlangıç kaydı sistemden tamamen kaldırılacak. Mac açılışında artık otomatik başlamayacaktır."),
                primaryButton: .destructive(Text("Kaldır")) {
                    if let item = itemToDelete {
                        Task {
                            _ = await engine.removeItem(item)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Vazgeç"))
            )
        }
    }
    
    // MARK: - Üst Başlık Çubuğu
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Başlangıç & Arka Plan Yöneticisi")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(engine.items.count) Servis")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text("Mac açıldığında otomatik başlayan uygulamaları ve arka planda bellek tüketen servisleri denetleyin.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                // Kırık / Ölü Kayıtları Tek Hamlede Temizle Butonu
                if engine.brokenCount > 0 {
                    Button(action: {
                        Task {
                            isCleaningBroken = true
                            _ = await engine.cleanAllBroken()
                            isCleaningBroken = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isCleaningBroken {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 13))
                            }
                            Text("Ölü Kayıtları Temizle (\(engine.brokenCount))")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(hex: "EF4444").opacity(0.2))
                        .foregroundColor(Color(hex: "F87171"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "EF4444").opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Yenile Butonu
                Button(action: {
                    Task {
                        await engine.scanAllItems()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("Yenile")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white.opacity(0.85))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Filtre ve Arama Çubuğu
    private var filterAndSearchBar: some View {
        HStack(spacing: 12) {
            // Segmented Kategori Butonları
            HStack(spacing: 4) {
                ForEach(StartupCategoryFilter.allCases) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11))
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: selectedFilter == filter ? .bold : .medium))
                            
                            // Sayı Rozeti
                            let count = countForFilter(filter)
                            Text("\(count)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(selectedFilter == filter ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedFilter == filter ? Color(hex: "8B5CF6").opacity(0.4) : Color.white.opacity(0.04))
                        .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(selectedFilter == filter ? Color(hex: "8B5CF6").opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Arama Kutusu
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                TextField("Uygulama veya servis ara...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(7)
            .frame(width: 200)
        }
    }
    
    // MARK: - Tekil Öğe Satırı
    private var iconPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .frame(width: 36, height: 36)
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "8B5CF6"))
        }
    }
    
    @ViewBuilder
    private func itemIcon(item: StartupItem) -> some View {
        if !item.path.isEmpty && item.path != "missing value" && FileManager.default.fileExists(atPath: item.path) {
            let nsImage = NSWorkspace.shared.icon(forFile: item.path)
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .cornerRadius(7)
        } else {
            iconPlaceholder
        }
    }

    private func startupItemRow(item: StartupItem) -> some View {
        HStack(spacing: 12) {
            // 1. İkon
            itemIcon(item: item)
            
            // 2. Bilgiler (Ad, Geliştirici, Yol / Hata)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(item.isBroken ? Color(hex: "F87171") : .white)
                    
                    // Tip Rozeti
                    Text(item.type.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeBadgeColor(item.type).opacity(0.2))
                        .foregroundColor(typeBadgeColor(item.type))
                        .cornerRadius(4)
                    
                    // Geliştirici Rozeti
                    Text(item.vendor)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white.opacity(0.7))
                        .cornerRadius(4)
                    
                    // Kırık / Ölü Kayıt Uyarısı
                    if item.isBroken {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("Diskte Bulunamadı / Kırık")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "EF4444").opacity(0.25))
                        .foregroundColor(Color(hex: "FCA5A5"))
                        .cornerRadius(4)
                    }
                }
                
                // Hedef Dosya Yolu
                Text(item.path.isEmpty || item.path == "missing value" ? (item.plistPath ?? "Bilinmeyen Yol") : item.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // 3. Eylemler: Açma/Kapama Toggle ve Silme Butonu
            HStack(spacing: 12) {
                // Toggle Butonu (Etkin / Devre Dışı)
                Button(action: {
                    Task {
                        _ = await engine.toggleItem(item)
                    }
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.isEnabled ? Color(hex: "10B981") : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                        Text(item.isEnabled ? "Açılışta Etkin" : "Devre Dışı")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(item.isEnabled ? Color(hex: "10B981").opacity(0.15) : Color.white.opacity(0.06))
                    .foregroundColor(item.isEnabled ? Color(hex: "34D399") : .white.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(item.isEnabled ? Color(hex: "10B981").opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                // Kaldır Butonu (Çöp Sepeti)
                Button(action: {
                    itemToDelete = item
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Bu başlangıç kaydını tamamen kaldır")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.isBroken ? Color(hex: "EF4444").opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.isBroken ? Color(hex: "EF4444").opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Boş Durum
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "10B981"))
            Text("Seçili filtrede herhangi bir kayıt bulunamadı.")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Mac başlangıç ve arka plan listeniz temiz ve düzenli.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
    }
    
    // MARK: - Yardımcı Renkler & Sayılar
    private func typeBadgeColor(_ type: StartupItemType) -> Color {
        switch type {
        case .loginItem:
            return Color(hex: "3B82F6") // Mavi
        case .launchAgent:
            return Color(hex: "8B5CF6") // Mor
        case .launchDaemon:
            return Color(hex: "F59E0B") // Kehribar
        }
    }
    
    private func countForFilter(_ filter: StartupCategoryFilter) -> Int {
        switch filter {
        case .all:
            return engine.items.count
        case .loginItems:
            return engine.items.filter { $0.type == .loginItem }.count
        case .launchAgents:
            return engine.items.filter { $0.type == .launchAgent || $0.type == .launchDaemon }.count
        case .broken:
            return engine.brokenCount
        }
    }
}
