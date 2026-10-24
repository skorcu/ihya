import SwiftUI

public struct LiquidGlassOrbView: View {
    let isScanning: Bool
    let isCleaning: Bool
    let totalReclaimable: String
    let onStartAction: () -> Void
    
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0
    
    public init(
        isScanning: Bool,
        isCleaning: Bool,
        totalReclaimable: String,
        onStartAction: @escaping () -> Void
    ) {
        self.isScanning = isScanning
        self.isCleaning = isCleaning
        self.totalReclaimable = totalReclaimable
        self.onStartAction = onStartAction
    }
    
    public var body: some View {
        Button(action: onStartAction) {
            ZStack {
                // Arka Plan Işık Halesi (Glow Ambient)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isCleaning ? Color.green : (isScanning ? Color.cyan : Color.blue)).opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse)
                
                // Dönen Kristal Halka (Liquid Glass Orbit Ring)
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.cyan.opacity(0.2),
                                Color.blue,
                                Color.purple.opacity(0.7),
                                Color.cyan
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: isScanning ? [6, 10] : [])
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(rotation))
                
                // İç Sıvı Cam Göbek (Frosted Acrylic Core)
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 135, height: 135)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
                
                // Merkez İkon ve Metin
                VStack(spacing: 4) {
                    if isCleaning {
                        Image(systemName: "sparkles")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.green)
                        Text("Arındırılıyor...")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else if isScanning {
                        Image(systemName: "radar")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.cyan)
                        Text("Taranıyor...")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text(totalReclaimable.isEmpty || totalReclaimable == "0 bytes" || totalReclaimable == "Taramaya Hazır" ? "Sistemi Tara" : totalReclaimable)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(totalReclaimable.isEmpty || totalReclaimable == "0 bytes" || totalReclaimable == "Taramaya Hazır" ? "Tek Dokunuş" : "Şimdi Arındır")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 180, height: 180)
        .onAppear {
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = 1.1
            }
        }
    }
}
