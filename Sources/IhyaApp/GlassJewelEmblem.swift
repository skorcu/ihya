import SwiftUI

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// CleanMyMac-kalitesinde 3D Sıvı Cam Mücevher Rozetleri
public struct GlassJewelEmblem: View {
    public enum Style {
        case emerald   // Sistem Çöpleri
        case violet    // Hayalet Servisler & Koruma
        case sapphire  // Çift Dosyalar & Dağınıklık
        case amber     // Geliştirici Kasası
        case rose      // Uygulama İnceltici
        case crimson   // Derin Kaldırıcı
        case cyan      // Hacim Röntgeni (Space Lens)
        case mint      // Sistem & Bellek Arındırma
    }
    
    let style: Style
    let iconName: String
    var size: CGFloat = 64
    
    public init(style: Style, iconName: String, size: CGFloat = 64) {
        self.style = style
        self.iconName = iconName
        self.size = size
    }
    
    private var gradientColors: [Color] {
        switch style {
        case .emerald:
            return [Color(hex: "34D399"), Color(hex: "059669"), Color(hex: "064E3B")]
        case .violet:
            return [Color(hex: "C084FC"), Color(hex: "7C3AED"), Color(hex: "4C1D95")]
        case .sapphire:
            return [Color(hex: "38BDF8"), Color(hex: "2563EB"), Color(hex: "1E3A8A")]
        case .amber:
            return [Color(hex: "FBBF24"), Color(hex: "D97706"), Color(hex: "78350F")]
        case .rose:
            return [Color(hex: "FB7185"), Color(hex: "E11D48"), Color(hex: "881337")]
        case .crimson:
            return [Color(hex: "F87171"), Color(hex: "DC2626"), Color(hex: "7F1D1D")]
        case .cyan:
            return [Color(hex: "67E8F9"), Color(hex: "06B6D4"), Color(hex: "164E63")]
        case .mint:
            return [Color(hex: "5EEAD4"), Color(hex: "0D9488"), Color(hex: "134E4A")]
        }
    }
    
    private var glowColor: Color {
        switch style {
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
    
    public var body: some View {
        ZStack {
            // Arka Ortam Parıltısı
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.45), Color.clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
            
            // 3D Dış Kristal Gövde
            RoundedRectangle(cornerRadius: size * 0.38, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.38, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.1),
                                    Color.black.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: glowColor.opacity(0.35), radius: 10, x: 0, y: 5)
            
            // İç Sıvı Cam Yansıması
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: size * 0.9, height: size * 0.45)
                .offset(y: -size * 0.22)
            
            // Merkez İkon
            Image(systemName: iconName)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .frame(width: size, height: size)
    }
}
