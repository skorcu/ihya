import SwiftUI
import AppKit
import IhyaCore

public struct LegalNoticeView: View {
    @State private var currentStep: Int = 1 // 1: Privacy & Liability, 2: Full Disk Access
    @State private var hasAccepted: Bool = false
    let onAccept: () -> Void
    
    public init(onAccept: @escaping () -> Void) {
        self.onAccept = onAccept
    }
    
    public var body: some View {
        ZStack {
            // Lüks Koyu Cam Zemin & Aurora
            LinearGradient(
                colors: [Color(hex: "170D33"), Color(hex: "0E0720"), Color(hex: "080415")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geo in
                Circle()
                    .fill(Color(hex: "7C3AED").opacity(0.3))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .blur(radius: 100)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.2)
                
                Circle()
                    .fill(Color(hex: "059669").opacity(0.2))
                    .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                    .blur(radius: 90)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.3)
            }
            
            VStack(spacing: 0) {
                if currentStep == 1 {
                    step1PrivacyView
                } else {
                    step2FullDiskAccessView
                }
            }
        }
        .frame(width: 660, height: 520)
    }
    
    // MARK: - Adım 1: Gizlilik ve Sorumluluk Beyanı
    private var step1PrivacyView: some View {
        VStack(spacing: 0) {
            // Başlık Alanı
            HStack(spacing: 16) {
                GlassJewelEmblem(
                    style: .emerald,
                    iconName: "lock.shield.fill",
                    size: 48
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Güvenlik Güvencesi ve Yasal Beyan")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("İhyâ • %100 Yerel Mimari, Sıfır Telemetri & Güvenli Arındırma")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Kaydırılabilir İçerik
            ScrollView {
                VStack(spacing: 12) {
                    legalCard(
                        icon: "shield.checkered",
                        iconColor: Color(hex: "34D399"),
                        title: "1. %100 Cihaz İçi (On-Device) Çalışma & Sıfır Veri Toplama",
                        description: "İhyâ, tamamen kendi Mac'iniz üzerinde yerel olarak çalışır. Dosyalarınız, fotoğraflarınız, tarama sonuçlarınız ve sistem bilgileriniz ASLA ve HİÇBİR KOŞULDA harici bir sunucuya, üçüncü şahıslara veya geliştiriciye gönderilmez, kopyalanmaz ve kaydedilmez."
                    )
                    
                    legalCard(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Color(hex: "FBBF24"),
                        title: "2. Sistem Temizliği ve Dosya Silme Sorumluluk Reddi",
                        description: "İhyâ sistem temizleme ve arındırma motoru, kullanıcının onayıyla seçilen önbellekleri, logları, yetim artıkları veya çift dosyaları siler. Bu eylemler tamamen kullanıcının kendi hür iradesi ve inisiyatifindedir. Geliştirici; silinen, temizlenen veya kullanıcı tasarrufuyla kaybedilen hiçbir dosyadan, veriden veya doğabilecek maddi/manevi zarardan hukuki, cezai veya mali olarak sorumlu tutulamaz."
                    )
                    
                    legalCard(
                        icon: "lock.fill",
                        iconColor: Color(hex: "38BDF8"),
                        title: "3. SIP ve Sistem Koruma Kalkanı (SafetyFilter)",
                        description: "İhyâ; macOS System Integrity Protection (SIP) alanlarına, kullanıcı kişisel belgelerine (Belgeler, Fotoğraflar, Masaüstü, Şifreler) ASLA dokunmaz. Yalnızca güvenli olduğu Apple standartlarınca doğrulanmış geçici dosya ve artıklar hedeflenir."
                    )
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
            }
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Alt Onay Çubuğu
            VStack(spacing: 14) {
                Toggle(isOn: $hasAccepted) {
                    Text("Yukarıdaki güvenlik güvencesini, sıfır telemetri taahhüdünü ve dosya temizleme sorumluluk reddini okudum, anladım ve kabul ediyorum.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(Color(hex: "34D399"))
                            .font(.system(size: 12))
                        Text("macOS Güvenlik Standartlarına %100 Uyumlu")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "ihya_has_accepted_legal_terms")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep = 2
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("Devam Et")
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasAccepted)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.2))
        }
    }
    
    // MARK: - Adım 2: Tam Disk Erişimi (CleanMyMac Tarzı)
    private var step2FullDiskAccessView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 3D Disk Mücevher Rozet
            GlassJewelEmblem(
                style: .violet,
                iconName: "internaldrive.fill",
                size: 76
            )
            
            VStack(spacing: 8) {
                Text("Tam Disk Erişimi Tanımlayın")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("İhyâ'nın sistem önbelleklerini, logları ve ölü servisleri eksiksiz tarayabilmesi için\nmacOS Tam Disk Erişimi iznine ihtiyacı vardır.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            
            // 3 Maddelik Avantaj Hapları (CleanMyMac-tarzı)
            HStack(spacing: 14) {
                fdaPill(icon: "shield.fill", text: "Tam Koruma", color: Color(hex: "8B5CF6"))
                fdaPill(icon: "sparkles", text: "%27,5 Daha Fazla Çöp", color: Color(hex: "10B981"))
                fdaPill(icon: "folder.fill", text: "Eksiksiz Tarama", color: Color(hex: "0EA5E9"))
            }
            .padding(.top, 4)
            
            Spacer()
            
            // Alt Eylemler
            VStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                        Text("Sistem Ayarlarını Aç")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: 240)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Daha Sonra Yap veya Başla") {
                    onAccept()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 32)
    }
    
    private func fdaPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func legalCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 22, height: 22)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}
