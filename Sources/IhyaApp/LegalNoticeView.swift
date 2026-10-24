import SwiftUI
import AppKit
import Combine
import IhyaCore

public struct LegalNoticeView: View {
    @State private var currentStep: Int = 1 // 1: Privacy & Liability, 2: Full Disk Access
    @State private var hasAccepted: Bool = false
    @State private var hasFDA: Bool = FDAChecker.hasFullDiskAccess()
    @State private var isInstalledInApplications: Bool = FDAChecker.isInstalledInApplications()
    private let statusTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
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
        .frame(width: 680, height: 530)
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
    
    // MARK: - Adım 2: Tam Disk Erişimi (CleanMyMac & Apple Standartı)
    private var step2FullDiskAccessView: some View {
        VStack(spacing: 14) {
            // Başlık ve Canlı Durum Bandı
            HStack(spacing: 16) {
                GlassJewelEmblem(
                    style: hasFDA ? .emerald : .violet,
                    iconName: hasFDA ? "checkmark.shield.fill" : "internaldrive.fill",
                    size: 48
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(hasFDA ? "Tam Disk Erişimi Onaylandı" : "Tam Disk Erişimi Tanımlayın")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Canlı Durum Rozeti
                        HStack(spacing: 5) {
                            Circle()
                                .fill(hasFDA ? Color(hex: "10B981") : Color(hex: "F59E0B"))
                                .frame(width: 7, height: 7)
                            Text(hasFDA ? "Aktif ✓" : "İzin Bekleniyor")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(hasFDA ? Color(hex: "10B981") : Color(hex: "F59E0B"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((hasFDA ? Color(hex: "10B981") : Color(hex: "F59E0B")).opacity(0.14))
                        .cornerRadius(6)
                    }
                    
                    Text(hasFDA 
                         ? "macOS izin doğrulaması tamamlandı. İhyâ tüm önbellek ve artık dosyaları arındırmaya hazır." 
                         : "İhyâ'nın sistem önbelleklerini ve ölü servis artıklarını eksiksiz tarayabilmesi için tek seferlik macOS iznine ihtiyacı vardır.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.68))
                        .lineSpacing(2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Eğer İzin Henüz Verilmediyse: 3 Adımlı Net Rehber Kutusu
            if !hasFDA {
                VStack(spacing: 9) {
                    instructionRow(
                        num: "1",
                        icon: "gearshape.fill",
                        color: Color(hex: "38BDF8"),
                        title: "Sistem Ayarlarını Açın",
                        desc: "Aşağıdaki butona tıklayın. macOS Gizlilik ve Güvenlik > Tam Disk Erişimi sayfası açılır."
                    )
                    
                    instructionRow(
                        num: "2",
                        icon: "switch.2",
                        color: Color(hex: "A78BFA"),
                        title: "Listede İhyâ'yı Açık Konuma Getirin",
                        desc: "Açılan pencerede İhyâ'yı bularak yanındaki anahtarı açık (mavi) konuma getirin."
                    )
                    
                    instructionRow(
                        num: "3",
                        icon: "plus.circle.fill",
                        color: Color(hex: "34D399"),
                        title: "İhyâ Listede Görünmüyorsa (Apple Güvenlik Kuralı)",
                        desc: "macOS kuralları gereği yeni uygulamalar listede görünmeyebilir. Sol alttaki '+' butonuna basıp Uygulamalar'dan İhyâ'yı seçin veya aşağıdaki 'Finder'da İhyâ'yı Göster' butonuna basarak simgeyi doğrudan Sistem Ayarları listesine sürükleyin."
                    )
                }
                .padding(.horizontal, 28)
                
                if !isInstalledInApplications {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: "FBBF24"))
                            .font(.system(size: 11))
                        Text("İpucu: İhyâ'nın sorunsuz çalışması için Uygulamalar (Applications) klasörüne taşınması önerilir.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.75))
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 2)
                }
            } else {
                // İzin Verilmişse: Başarı Paneli
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 54))
                        .foregroundColor(Color(hex: "10B981"))
                    
                    Text("Tam Disk Erişimi Hazır!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("İhyâ sisteminizdeki tüm önbellek depolarını, geliştirici kalıntılarını ve çift dosyaları en yüksek performansla arındırmaya hazır.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            Divider()
                .overlay(Color.white.opacity(0.08))
            
            // Alt Eylemler
            HStack(spacing: 14) {
                if !hasFDA {
                    Button(action: {
                        FDAChecker.revealInFinder()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                            Text("Finder'da İhyâ'yı Göster")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .help("İhyâ uygulamasını Finder'da seçili olarak açar; böylece Sistem Ayarları'na sürükleyebilirsiniz.")
                    
                    Button(action: {
                        FDAChecker.openSystemSettings()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            Text("Sistem Ayarlarını Aç")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button("Daha Sonra Yap veya Başla") {
                        onAccept()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                } else {
                    Spacer()
                    
                    Button(action: {
                        onAccept()
                    }) {
                        HStack(spacing: 8) {
                            Text("İhyâ'yı Başlat")
                                .font(.system(size: 13, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "10B981"))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.2))
        }
        .onReceive(statusTimer) { _ in
            let fda = FDAChecker.hasFullDiskAccess()
            if fda != hasFDA {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    hasFDA = fda
                }
            }
            isInstalledInApplications = FDAChecker.isInstalledInApplications()
        }
    }
    
    private func instructionRow(num: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 26, height: 26)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(num). \(title)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
