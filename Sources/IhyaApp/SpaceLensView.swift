import SwiftUI
import AppKit
import IhyaCore

public struct SpaceLensView: View {
    @StateObject private var engine = SpaceLensEngine.shared
    @State private var hoveredNodeId: String? = nil
    @State private var searchQuery: String = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if engine.isScanning {
                scanningStateView
            } else if let current = engine.currentNode {
                scannedHierarchyView(current: current)
            } else {
                heroStageView
            }
        }
        .onAppear {
            if engine.currentNode == nil && !engine.isScanning {
                Task {
                    await engine.scan()
                }
            }
        }
    }
    
    // MARK: - 1. Boşta Durum (Hero Stage)
    private var heroStageView: some View {
        HeroStageView(
            title: "Hacim Röntgeni",
            subtitle: "Mac'inizin depolama haritasını interaktif halkalarla keşfedin ve devasa yer kaplayan gizli klasörleri ortaya çıkarın.",
            emblemStyle: .cyan,
            emblemIcon: "circle.hexagongrid.fill",
            bullets: [
                HeroStageView.BulletItem(
                    icon: "sun.max.fill",
                    title: "Dinamik Güneş Patlaması (Sunburst)",
                    description: "Hangi klasörün ne kadar yer kapladığını oransal renkli halkalarla görselleştirir."
                ),
                HeroStageView.BulletItem(
                    icon: "arrow.down.right.and.arrow.up.left",
                    title: "Derinlemesine Gezinme (Drill Down)",
                    description: "Klasörlere tıklayarak alt dizinlerin röntgenine anında dalın."
                ),
                HeroStageView.BulletItem(
                    icon: "trash.fill",
                    title: "Kusursuz Çöp Sepeti Güvencesi",
                    description: "Gereksiz devasa dosyalar asla yok edilmez; doğrudan macOS Çöp Sepeti'ne taşınır."
                )
            ],
            targetDiskInfo: " Macintosh HD · Kullanıcı Alanı (~)",
            buttonTitle: "Hacim Taramasını Başlat",
            buttonColorStyle: .electricCyan,
            isPulsing: true
        ) {
            Task {
                await engine.scan()
            }
        }
    }
    
    // MARK: - 2. Tarama Sürüyor Durumu (Lüks İlerleme Çubuğu)
    private var scanningStateView: some View {
        LuxuryScanningStageView(
            title: "Hacim Röntgeni Çekiliyor...",
            subtitle: "Mac'inizin depolama haritası taranıyor ve bloklar hesaplanıyor",
            emblemStyle: .cyan,
            emblemIcon: "circle.hexagongrid.fill",
            steps: ["1. Dizin Haritası", "2. Boyut Dağılımı", "3. Hacim Röntgeni"],
            currentStepIndex: 1,
            progressFraction: engine.progressFraction > 0 ? engine.progressFraction : 0.65,
            currentItemName: engine.scanProgressMessage
        )
    }
    
    // MARK: - 3. Taranmış Hiyerarşi & Röntgen Sahnesi
    private func scannedHierarchyView(current: LensNode) -> some View {
        VStack(spacing: 0) {
            // Üst Ekmek Kırıntısı (Breadcrumbs) & Yenileme Barı
            breadcrumbBar
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Ana Gövde (Sol: Sunburst Çarkı + Sağ: Klasör/Dosya Listesi)
            HStack(spacing: 24) {
                // Sol Bölüm: İnteraktif Sunburst Çarkı
                VStack(spacing: 16) {
                    sunburstCanvas(current: current)
                        .frame(width: 260, height: 260)
                    
                    VStack(spacing: 4) {
                        Text(current.name.isEmpty ? "Ev Dizinim" : current.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(current.formattedSize)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "22D3EE"))
                        
                        Text("\(current.children.count) alt öğe tespit edildi")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    Spacer()
                }
                .frame(width: 270)
                .padding(.leading, 24)
                .padding(.top, 20)
                
                // Sağ Bölüm: Boyut Sıralı Liste & Röntgen
                VStack(spacing: 0) {
                    // Arama & Filtre Çubuğu
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 11))
                        
                        TextField("Bu dizinde filtrele...", text: $searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
                    .padding(.trailing, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    
                    let filtered = current.children.filter {
                        searchQuery.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchQuery)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filtered) { node in
                                nodeRow(node)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.trailing, 24)
                    }
                    
                    // Alt İşlem Barı (Seçili öğe varsa gösterilir)
                    if !engine.selectedNodeIds.isEmpty {
                        actionBar
                            .padding(.horizontal, 24)
                            .padding(.bottom, 14)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Breadcrumb Gezinti Çubuğu
    private var breadcrumbBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundColor(Color(hex: "06B6D4"))
                .font(.system(size: 12))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(engine.pathBreadcrumbs.enumerated()), id: \.offset) { index, node in
                        Button(action: {
                            engine.navigateBack(to: index)
                        }) {
                            Text(index == 0 ? "Ana Dizin" : node.name)
                                .font(.system(size: 12, weight: index == engine.pathBreadcrumbs.count - 1 ? .bold : .medium))
                                .foregroundColor(index == engine.pathBreadcrumbs.count - 1 ? .white : .white.opacity(0.6))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if index < engine.pathBreadcrumbs.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                engine.selectAndScanFolder()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Klasör Seç...")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Özel bir klasörü veya harici diski seçerek tara")
            
            Button(action: {
                Task {
                    await engine.scan(path: engine.currentNode?.path)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Tazele")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - İnteraktif Sunburst Çarkı (SwiftUI Canvas)
    private func sunburstCanvas(current: LensNode) -> some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius: CGFloat = min(size.width, size.height) / 2 - 10
                let innerRadius: CGFloat = radius * 0.58
                
                var startAngle = Angle(degrees: -90)
                
                for node in current.children.prefix(12) {
                    let sweep = Angle(degrees: node.percentage * 360)
                    let endAngle = startAngle + sweep
                    
                    var path = Path()
                    path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                    path.closeSubpath()
                    
                    let nodeColor = Color(hex: node.colorHex)
                    let isHovered = hoveredNodeId == node.id
                    
                    context.fill(path, with: .color(isHovered ? nodeColor : nodeColor.opacity(0.85)))
                    context.stroke(path, with: .color(Color.black.opacity(0.4)), lineWidth: 1.5)
                    
                    startAngle = endAngle
                }
            }
            
            // Merkez Cam Halka
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: 140, height: 140)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            VStack(spacing: 2) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "22D3EE"))
                
                Text(current.formattedSize)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Tekil Öğe Satırı
    private func nodeRow(_ node: LensNode) -> some View {
        let isSelected = engine.selectedNodeIds.contains(node.id)
        
        return HStack(spacing: 12) {
            // Seçim Kutusu
            Button(action: {
                if isSelected {
                    engine.selectedNodeIds.remove(node.id)
                } else {
                    engine.selectedNodeIds.insert(node.id)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? Color(hex: "06B6D4") : .white.opacity(0.3))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Tıklanabilir İçerik: Simge, Başlık & Yüzdelik İlerleme Çubuğu (Klasöre Girer)
            Button(action: {
                if node.isDirectory {
                    engine.drillDown(to: node)
                }
            }) {
                HStack(spacing: 12) {
                    // Simge
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: node.colorHex).opacity(0.2))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: node.colorHex))
                    }
                    
                    // Başlık & Yüzdelik İlerleme Çubuğu
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(node.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(node.formattedSize)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        // Mini Yüzdelik Çubuğu
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 4)
                                
                                Capsule()
                                    .fill(Color(hex: node.colorHex))
                                    .frame(width: max(geo.size.width * CGFloat(node.percentage), 4), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Klasör ise Derinleş (Drill Down) Butonu
            if node.isDirectory {
                Button(action: {
                    engine.drillDown(to: node)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Finder'da Göster
            Button(action: {
                let url = URL(fileURLWithPath: node.path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(6)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Finder'da Konumu Göster")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color(hex: "06B6D4").opacity(0.14) : Color.white.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color(hex: "06B6D4").opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredNodeId = hovering ? node.id : nil
        }
    }
    
    // MARK: - Alt Eylem Çubuğu (Geri Alınabilir Çöp Sepeti)
    private var actionBar: some View {
        let selectedCount = engine.selectedNodeIds.count
        let totalSelectedBytes = engine.currentNode?.children
            .filter { engine.selectedNodeIds.contains($0.id) }
            .reduce(0) { $0 + $1.size } ?? 0
        let formattedSelectedSize = ByteCountFormatter.string(fromByteCount: totalSelectedBytes, countStyle: .file)
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedCount) Öğe Seçildi")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(formattedSelectedSize) alan Çöp Sepeti'ne taşınacak (Geri Alınabilir)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: {
                let freed = engine.recycleSelectedNodes()
                if freed > 0 {
                    SoundManager.shared.playSuccessChime()
                    HapticManager.shared.generateSuccessFeedback()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Çöp Kutusuna Taşı")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "EF4444"))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "1F1F24").opacity(0.95))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}
