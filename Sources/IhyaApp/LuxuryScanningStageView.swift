import SwiftUI

public struct LuxuryScanningStageView: View {
    public let title: String
    public let subtitle: String
    public let emblemStyle: GlassJewelEmblem.Style
    public let emblemIcon: String
    public let steps: [String]
    public let currentStepIndex: Int
    public let progressFraction: Double
    public let currentItemName: String?
    public let onCancel: (() -> Void)?
    
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0
    
    public init(
        title: String,
        subtitle: String,
        emblemStyle: GlassJewelEmblem.Style = .sapphire,
        emblemIcon: String,
        steps: [String] = ["1. Ön Tanımlama", "2. Derin Analiz", "3. Hacim Hesabı"],
        currentStepIndex: Int = 1,
        progressFraction: Double = 0.5,
        currentItemName: String? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emblemStyle = emblemStyle
        self.emblemIcon = emblemIcon
        self.steps = steps
        self.currentStepIndex = currentStepIndex
        self.progressFraction = progressFraction
        self.currentItemName = currentItemName
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 22) {
            Spacer()
            
            // 1. Üst Dönen & Nabız Atan Cam Rozet
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: "38BDF8").opacity(0.8),
                                Color(hex: "0284C7").opacity(0.1),
                                Color(hex: "38BDF8").opacity(0.8)
                            ],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: Color(hex: "0284C7").opacity(0.5), radius: 14)
                
                GlassJewelEmblem(
                    style: emblemStyle,
                    iconName: emblemIcon,
                    size: 88
                )
                .scaleEffect(pulse)
            }
            .padding(.bottom, 6)
            
            // 2. Başlık ve Açıklama
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // 3. 3 Aşamalı Breadcrumb Adımları
            HStack(spacing: 12) {
                ForEach(steps.indices, id: \.self) { idx in
                    HStack(spacing: 6) {
                        if idx < currentStepIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "34D399"))
                                .font(.system(size: 11))
                        } else if idx == currentStepIndex {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(steps[idx])
                            .font(.system(size: 11, weight: idx == currentStepIndex ? .bold : .medium))
                            .foregroundColor(idx == currentStepIndex ? .white : .white.opacity(0.5))
                    }
                    
                    if idx < steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(20)
            
            // 4. Akıcı Gradyanlı İlerleme Çubuğu ve Yüzde
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "0284C7"), Color(hex: "38BDF8"), Color(hex: "34D399")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(14, geo.size.width * CGFloat(min(1.0, max(0.02, progressFraction)))))
                            .shadow(color: Color(hex: "38BDF8").opacity(0.6), radius: 8)
                    }
                }
                .frame(width: 440, height: 7)
                
                HStack {
                    Text("\(Int(min(1.0, max(0.0, progressFraction)) * 100))%")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "38BDF8"))
                    
                    Spacer()
                    
                    if let cancelAction = onCancel {
                        Button(action: cancelAction) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Durdur")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 440)
            }
            
            // 5. Canlı İncelenen Öğe Kapsülü
            if let currentItem = currentItemName, !currentItem.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "38BDF8"))
                    
                    Text(currentItem)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(maxWidth: 500)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = 1.05
            }
        }
    }
}
