import SwiftUI
import AppKit

public struct HeroStageView: View {
    public struct BulletItem: Identifiable {
        public let id = UUID()
        public let icon: String
        public let title: String
        public let description: String
        
        public init(icon: String, title: String, description: String) {
            self.icon = icon
            self.title = title
            self.description = description
        }
    }
    
    let title: String
    let subtitle: String
    let emblemStyle: GlassJewelEmblem.Style
    let emblemIcon: String
    let bullets: [BulletItem]
    let targetDiskInfo: String
    let buttonTitle: String
    let buttonColorStyle: FloatingActionButton.ColorStyle
    let isPulsing: Bool
    let onAction: () -> Void
    
    public init(
        title: String,
        subtitle: String,
        emblemStyle: GlassJewelEmblem.Style,
        emblemIcon: String,
        bullets: [BulletItem],
        targetDiskInfo: String = " Macintosh HD (Mevcut Disk) · APFS",
        buttonTitle: String = "Taramayı Başlat",
        buttonColorStyle: FloatingActionButton.ColorStyle = .primaryViolet,
        isPulsing: Bool = false,
        onAction: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emblemStyle = emblemStyle
        self.emblemIcon = emblemIcon
        self.bullets = bullets
        self.targetDiskInfo = targetDiskInfo
        self.buttonTitle = buttonTitle
        self.buttonColorStyle = buttonColorStyle
        self.isPulsing = isPulsing
        self.onAction = onAction
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isCompactWidth = geo.size.width < 720
            let isCompactHeight = geo.size.height < 540
            let emblemSize: CGFloat = isCompactWidth ? 112 : (isCompactHeight ? 118 : 136)
            let emblemColWidth: CGFloat = isCompactWidth ? 144 : 180
            let stageSpacing: CGFloat = isCompactWidth ? 24 : min(44, geo.size.width * 0.05)
            let horizPadding: CGFloat = isCompactWidth ? 18 : 32
            
            VStack(spacing: 0) {
                Spacer(minLength: isCompactHeight ? 8 : 16)
                
                // Hero Sahne Gövdesi (Sol: 3D Mücevher, Sağ: Açıklama ve Maddeler) - TAM DUYARLI (RESPONSIVE)
                HStack(alignment: .center, spacing: stageSpacing) {
                    // Sol: 3D Büyük Mücevher Rozet
                    VStack {
                        ZStack {
                            Circle()
                                .fill(emblemColor.opacity(0.35))
                                .frame(width: emblemSize * 1.6, height: emblemSize * 1.6)
                                .blur(radius: 40)
                            
                            GlassJewelEmblem(
                                style: emblemStyle,
                                iconName: emblemIcon,
                                size: emblemSize
                            )
                        }
                    }
                    .frame(width: emblemColWidth)
                    
                    // Sağ: Başlık, Alt Başlık ve 3 Maddelik Özet
                    VStack(alignment: .leading, spacing: isCompactHeight ? 12 : 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: isCompactWidth ? 22 : 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            
                            Text(subtitle)
                                .font(.system(size: isCompactWidth ? 11 : 12.5))
                                .foregroundColor(.white.opacity(0.72))
                                .lineSpacing(isCompactHeight ? 2 : 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // 3 Maddelik Özellikler
                        VStack(alignment: .leading, spacing: isCompactHeight ? 8 : 12) {
                            ForEach(bullets) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [emblemColor, emblemColor.opacity(0.75)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: isCompactHeight ? 22 : 26, height: isCompactHeight ? 22 : 26)
                                            .shadow(color: emblemColor.opacity(0.5), radius: 5, x: 0, y: 2)
                                        
                                        Image(systemName: item.icon)
                                            .font(.system(size: isCompactHeight ? 10 : 12, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title)
                                            .font(.system(size: isCompactWidth ? 11 : 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(item.description)
                                            .font(.system(size: isCompactWidth ? 10 : 11))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineSpacing(1.5)
                                    }
                                }
                            }
                        }
                        
                        // Hedef Sürücü Rozeti
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(emblemColor)
                            
                            Text(targetDiskInfo)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        .frame(height: 30)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: 480)
                }
                .padding(.horizontal, horizPadding)
                
                Spacer(minLength: isCompactHeight ? 10 : 18)
                
                // Alt Yüzen Düğme
                FloatingActionButton(
                    title: buttonTitle,
                    icon: "sparkles",
                    shortcutHint: "⌘↩",
                    isPulsing: isPulsing,
                    colorStyle: buttonColorStyle,
                    action: onAction
                )
                .padding(.bottom, isCompactHeight ? 16 : 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var emblemColor: Color {
        switch emblemStyle {
        case .emerald: return Color(hex: "10B981")
        case .violet: return Color(hex: "8B5CF6")
        case .sapphire: return Color(hex: "0EA5E9")
        case .amber: return Color(hex: "F59E0B")
        case .rose: return Color(hex: "F43F5E")
        case .crimson: return Color(hex: "EF4444")
        case .cyan: return Color(hex: "06B6D4")
        case .mint: return Color(hex: "14B8A6")
        }
    }
}
