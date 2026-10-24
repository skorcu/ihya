import SwiftUI

public struct FloatingActionButton: View {
    let title: String
    let icon: String
    let shortcutHint: String?
    let isPulsing: Bool
    let colorStyle: ColorStyle
    let action: () -> Void
    
    public enum ColorStyle {
        case primaryViolet
        case goldenAmber
        case sapphireBlue
        case royalPurple
        case sunsetRose
        case successEmerald
        case dangerStop
        case electricCyan
        case freshMint
    }
    
    @State private var pulse: CGFloat = 1.0
    
    public init(
        title: String,
        icon: String = "sparkles",
        shortcutHint: String? = "⌘↩",
        isPulsing: Bool = false,
        colorStyle: ColorStyle = .primaryViolet,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.shortcutHint = shortcutHint
        self.isPulsing = isPulsing
        self.colorStyle = colorStyle
        self.action = action
    }
    
    private var gradientColors: [Color] {
        switch colorStyle {
        case .primaryViolet:
            return [Color(hex: "C084FC"), Color(hex: "7C3AED"), Color(hex: "4C1D95")]
        case .goldenAmber:
            return [Color(hex: "FCD34D"), Color(hex: "F59E0B"), Color(hex: "B45309")]
        case .sapphireBlue:
            return [Color(hex: "38BDF8"), Color(hex: "0284C7"), Color(hex: "0369A1")]
        case .royalPurple:
            return [Color(hex: "E879F9"), Color(hex: "A855F7"), Color(hex: "6B21A8")]
        case .sunsetRose:
            return [Color(hex: "FDA4AF"), Color(hex: "F43F5E"), Color(hex: "9F1239")]
        case .successEmerald:
            return [Color(hex: "34D399"), Color(hex: "059669"), Color(hex: "064E3B")]
        case .dangerStop:
            return [Color(hex: "F43F5E"), Color(hex: "BE123C"), Color(hex: "881337")]
        case .electricCyan:
            return [Color(hex: "67E8F9"), Color(hex: "0891B2"), Color(hex: "155E75")]
        case .freshMint:
            return [Color(hex: "5EEAD4"), Color(hex: "0D9488"), Color(hex: "115E59")]
        }
    }
    
    private var glowColor: Color {
        switch colorStyle {
        case .primaryViolet: return Color(hex: "A855F7")
        case .goldenAmber: return Color(hex: "F59E0B")
        case .sapphireBlue: return Color(hex: "0284C7")
        case .royalPurple: return Color(hex: "9333EA")
        case .sunsetRose: return Color(hex: "F43F5E")
        case .successEmerald: return Color(hex: "10B981")
        case .dangerStop: return Color(hex: "F43F5E")
        case .electricCyan: return Color(hex: "0891B2")
        case .freshMint: return Color(hex: "0D9488")
        }
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                if let hint = shortcutHint {
                    Text(hint)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.28))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                        )
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 12.5)
            .background(
                ZStack {
                    // Dış Neon Parıltı
                    Capsule(style: .continuous)
                        .fill(glowColor.opacity(0.45))
                        .blur(radius: 12)
                        .scaleEffect(isPulsing ? pulse : 1.0)
                    
                    // Ana Düğme Gövdesi (Pill Shape)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: glowColor.opacity(0.55), radius: 10, x: 0, y: 4)
                    
                    // Üst Sıvı Cam Parıltısı
                    VStack {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 18)
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                        Spacer()
                    }
                    
                    // Dış İnce Cam Çerçeve
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.85), Color.white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [.command])
        .onAppear {
            if isPulsing {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = 1.08
                }
            }
        }
    }
}
