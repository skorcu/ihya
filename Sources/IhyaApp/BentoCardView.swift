import SwiftUI
import IhyaCore

public struct BentoCardView: View {
    let title: String
    let subtitle: String
    let statusText: String
    let isCompleted: Bool
    let isCleaned: Bool
    let isActive: Bool
    let emblemStyle: GlassJewelEmblem.Style
    let emblemIcon: String
    let itemsBreakdown: [(name: String, size: String)]?
    let reviewButtonTitle: String?
    let onClick: () -> Void
    
    @State private var isHovered: Bool = false
    
    public init(
        title: String,
        subtitle: String,
        statusText: String = "",
        isCompleted: Bool = false,
        isCleaned: Bool = false,
        isActive: Bool = false,
        emblemStyle: GlassJewelEmblem.Style,
        emblemIcon: String,
        itemsBreakdown: [(name: String, size: String)]? = nil,
        reviewButtonTitle: String? = "İncele",
        onClick: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.isCompleted = isCompleted
        self.isCleaned = isCleaned
        self.isActive = isActive
        self.emblemStyle = emblemStyle
        self.emblemIcon = emblemIcon
        self.itemsBreakdown = itemsBreakdown
        self.reviewButtonTitle = reviewButtonTitle
        self.onClick = onClick
    }
    
    public var body: some View {
        Button(action: onClick) {
            ZStack(alignment: .topLeading) {
                // Kart Zemin Işıltısı
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.14 : (isHovered ? 0.10 : 0.06)),
                                Color.white.opacity(isActive ? 0.06 : (isHovered ? 0.04 : 0.02))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isActive ? 0.40 : (isHovered ? 0.28 : 0.15)),
                                        Color.white.opacity(isHovered ? 0.10 : 0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.4 : 0.25), radius: isHovered ? 18 : 12, x: 0, y: isHovered ? 8 : 5)
                
                // Kart İçeriği
                VStack(alignment: .leading, spacing: 10) {
                    // Üst Başlık & Durum
                    HStack {
                        Text(title.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .tracking(0.6)
                        
                        Spacer()
                        
                        if isActive {
                            HStack(spacing: 5) {
                                ProgressView()
                                    .scaleEffect(0.55)
                                    .frame(width: 12, height: 12)
                                Text("Taranıyor...")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "06B6D4"))
                            }
                        } else if isCleaned {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "10B981"))
                                    .font(.system(size: 13, weight: .bold))
                                Text("Arındırıldı")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "10B981"))
                            }
                        } else if isCompleted {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: "38BDF8"))
                                    .frame(width: 6, height: 6)
                                Text("Hazır")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: "38BDF8"))
                            }
                        }
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Aktif Tarama Canlı Listesi (Hero Card Görünümü)
                    if let breakdown = itemsBreakdown, !breakdown.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(breakdown.prefix(4), id: \.name) { item in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(item.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.size)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        // Alt Bölüm: Büyük Metrik Değeri & İncele Butonu
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(subtitle)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                
                                if !statusText.isEmpty {
                                    Text(statusText)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if (isCompleted || isCleaned) && reviewButtonTitle != nil {
                                HStack(spacing: 4) {
                                    Text(reviewButtonTitle!)
                                        .font(.system(size: 10, weight: .bold))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(isHovered ? 0.22 : 0.12))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(18)
                
                // Sağ Üst/Orta 3D Cam Mücevher
                VStack {
                    HStack {
                        Spacer()
                        GlassJewelEmblem(
                            style: emblemStyle,
                            iconName: emblemIcon,
                            size: itemsBreakdown != nil ? 72 : 56
                        )
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}
