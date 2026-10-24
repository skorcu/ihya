# 💎 İhyâ (Mac) — Yeni Nesil macOS Arınma & Canlanma Motoru

<div align="center">
  <img src="Resources/icon_1024.png" width="128" height="128" alt="İhyâ Logo" />
  <br />
  <h3>Işık Hızında, %100 Yerel ve Gizlilik Odaklı macOS Temizlik & Optimizasyon Aracı</h3>
  <p>Apple Silicon (arm64) ve Intel (x86_64) Universal 2 Mimarisiyle Sıfır Tavizli Performans</p>

  [![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg?style=flat-square&logo=apple)](https://caneser.com/ihya)
  [![Swift](https://img.shields.io/badge/Swift-6.0-F05138.svg?style=flat-square&logo=swift)](https://swift.org)
  [![Architecture](https://img.shields.io/badge/Architecture-Universal%202%20(arm64%20%2B%20x86__64)-success.svg?style=flat-square)](https://caneser.com/ihya)
  [![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
</div>

---

## 🌟 Öne Çıkan Yetenekler

İhyâ, geleneksel abonelik tuzaklarına ve sistem kaynaklarını tüketen hantal temizleyicilere karşı **%100 yerel (offline-first)**, Swift 6 ve modern SwiftUI ile baştan sona inşa edilmiş bağımsız bir macOS sistem arındırma ve performans motorudur.

### 1. 🧹 Akıllı Arınma (Smart Care Bento Stage)
- Kullanıcı önbellekleri, sistem günlükleri, çökme tanı raporları ve unutulmuş disk kalıplarını tek tıkla arındırır.
- Canlı dosya yolu izleme (CleanMyMac seviyesinde anlık ticker).
- Kesin güvenlik kalkanı: Sistem ve kullanıcı için kritik hiçbir dosya silinmez.

### 2. 🌐 Tarayıcı & Web Kasası (21+ Tarayıcı Desteği)
- **Safari, Google Chrome, Firefox, Brave, Arc, Edge, Opera, Vivaldi, Orion** ve tüm Chromium türevlerini otomatik algılar.
- WebKit & V8 kod önbellekleri, favikon veritabanları, geçici web medyaları ve izleme çerezlerini güvenle temizler.
- Açık tarayıcıları tespit eder ve tek tıkla zarifçe kapatma imkânı sunar.

### 3. 🔄 Yazılım Güncelleyici (App Updater Hub)
- Mac'inizde kurulu tüm uygulamaları tarar.
- **Sparkle Appcast XML** beslemelerini ve **Homebrew Cask** paketlerini anlık sorgulayarak yeni sürümleri tespit eder.
- Versiyon karşılaştırma rozetleri (`v1.2.0 → v1.3.0`), resmi değişiklik notları ve tek tıkla güncelleme köprüleri.

### 4. 👯 Çift Dosya Avcısı (Multi-Target Duplicate Finder)
- İndirilenler, Masaüstü, Belgeler, Resimler, Filmler, Harici Diskler (`/Volumes/*`) ve Özel Klasörler arasında çapraz tarama.
- **SHA-256 Parçalı Hash Algoritması**: Dosya adı tamamen farklı olsa dahi içeriği bire bir aynı olan görsel, video ve belgeleri kesin olarak bulur.
- Akıllı koruma kuralları: *"Şu klasördekileri koru"*, *"En yeniyi koru"*, *"En eskiyi koru"*.
- Klasörler bazında hiyerarşik raporlama ve tek tıkla *"Eş Değil / Yoksay"* mekanizması.

### 5. 🪐 Hacim Röntgeni (Interactive Space Lens)
- Mac'inizin depolama haritasını interaktif kozmik halkalarla (sunburst) görselleştirir.
- Klasörlere tıklayarak alt dizinlerin derinliklerine anında dalma (Drill-Down).
- Silinen dosyaları macOS Çöp Sepeti güvencesiyle korur.

### 6. ✂️ Mimari İnceltici (Universal Binary Lipo)
- Apple Silicon işlemcili Mac'lerde uygulamaların içindeki gereksiz Intel (x86_64) mimari kodlarını ayıklar ve gigabaytlarca boş alan kazandırır.

### 7. 🛡️ Hayalet Servisler & Sistem Belleği
- Kaldırdığınız programlardan arta kalan ölü arka plan ajanlarını (`LaunchDaemons`, `LaunchAgents`) temizler, arka plan pil ve işlemci tüketimini sıfırlar.
- Tek dokunuşla RAM optimizasyonu ve DNS önbellek boşaltma.

---

## 🛠️ Kaynak Koddan Derleme (Build from Source)

### Gereksinimler
- macOS Sonoma 14.0 veya üzeri (macOS Sequoia 15.0+ ve macOS 27 uyumlu)
- Xcode 16+ ve Swift 6.0 araç seti

```bash
# Repoyu klonlayın
git clone https://github.com/skorcu/ihya.git
cd ihya

# Debug derlemesi
swift build

# Yerel CLI olarak çalıştırma
swift run ihya scan
```

### Apple Universal 2 (.app & .dmg) Paketleme

```bash
./package_app.sh
```

Bu betik:
1. `arm64` (Apple Silicon) için derler.
2. `x86_64` (Intel) için derler.
3. `lipo` ile iki mimariyi tek bir **Universal 2** ikili dosyada birleştirir.
4. `İhyâ.app` paketini tanzim eder ve Apple sertifikasıyla imzalar.
5. Son kullanıcı için `Ihya.dmg` imajını üretir.

---

## 🔒 Güvenlik ve Gizlilik İlkesi

- **Sıfır Telemetri Casusluğu**: Kişisel dosyalarınız, belgeleriniz veya gezinti geçmişiniz ASLA dış sunuculara iletilmez.
- **Donanım Mühürlü Lisanslama**: Lisanslama işlemleri tamamen cihazınızın donanım kimliğiyle kriptografik olarak doğrulanır.
- **Tahribatsız Temizlik**: Silinen tüm kullanıcı dosyaları kalıcı olarak silinmek yerine güvenli macOS Çöp Sepeti'ne aktarılır.

---

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) altında sunulmaktadır.
İhyâ markası ve logosu Can Eser / sarkacadam.com'a aittir.
