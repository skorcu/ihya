# 💎 İhyâ (Mac) — Yeni Nesil Saf macOS Arınma & Canlanma Motoru

<div align="center">
  <img src="Resources/icon_1024.png" width="128" height="128" alt="İhyâ macOS Logo" />
  <br />
  <h2>Işık Hızında, %100 Yerel ve Gizlilik Odaklı macOS Sistem Arınma & Hız Mimarisi</h2>
  <p><b>Apple Silicon (M1/M2/M3/M4) ve Intel (x86_64) Universal 2 Mimarisiyle Sıfır Tavizli Saf Performans</b></p>
  <p>
    <img src="https://img.shields.io/badge/Platform-macOS_14+_Sonoma_|_Sequoia-000000?style=flat-square&logo=apple&logoColor=white" />
    <img src="https://img.shields.io/badge/Mimari-Universal_2_(arm64_+_x86__64)-8B5CF6?style=flat-square" />
    <img src="https://img.shields.io/badge/Swift-5.10_|_SwiftUI-F05138?style=flat-square&logo=swift&logoColor=white" />
    <img src="https://img.shields.io/badge/Sürüm-v1.6.3-10B981?style=flat-square" />
    <img src="https://img.shields.io/badge/Lisans-Proprietary_(Telif_Korumalı)-blue?style=flat-square" />
  </p>
</div>

---

## 🌿 Sarkaç Adam'dan Mac Topluluğuna Bir Arınma Hediyesi

> *"Zihinsel berraklık ve fıtrî denge için kadim doğal kristallerin huzurunu ararken, her gün saatlerimizi geçirdiğimiz çalışma alanımız olan Mac'imizin de arınmış, hafif ve pürüzsüz olması gerektiğine inanıyoruz.*  
> *Sarkaç Adam olarak; geleneksel abonelik tuzaklarına ve sistemi yoran hantal araçlara inat, en saf Swift mühendisliğiyle geliştirdiğimiz **İhyâ**'yı tüm Mac kullanıcılarına **karşılıksız bir hediye** olarak takdim ediyoruz.*  
> *Mac'iniz ilk günkü saf hızına kavuşurken, sizleri de çalışma masanıza sükûnet ve denge katacak doğal kristallerimizle tanışmaya davet ediyoruz."*

---

## ⚡ Neden İhyâ? (Temel Farklar ve Karşılaştırma)

Geleneksel Mac temizleyicileri genellikle arka planda sürekli çalışan ağır servislerle sistemi yorar, aylık abonelikler talep eder ve yüzlerce megabaytlık yer kaplar. **İhyâ**, macOS'un en modern yerel kütüphaneleriyle (SwiftUI, Combine, Darwin Kernel APIs, AppKit) sıfırdan geliştirilmiştir.

*Test Ortamı: Apple M-Serisi Apple Silicon & APFS SSD • 1.200.000 Dosya Havuzu*

| Metrik & Standart | 💎 **İhyâ (v1.6.3 Universal 2)** | 📦 **Geleneksel Abonelikli Araçlar** |
| :--- | :--- | :--- |
| **Uygulama İkili Boyutu** | **2.8 MB** (Saf Swift Makine Kodu) | **180 MB – 260 MB** (Ağır Frameworkler) |
| **Arka Planda RAM Tüketimi** | **0.0 MB** (Beklemede Servis Çalıştırmaz) | **180 MB – 350 MB** (24/7 Arka Plan Daemons) |
| **Tam Sistem Tarama Hızı** | **~4 - 8 Saniye** (Çok Çekirdekli Eşzamanlı) | **45 - 90 Saniye** (Tek Çekirdek Kısıtı) |
| **Çift Dosya Analizi** | **3 Aşamalı SHA-256** (Ön-hash + Tam Hash) | **Yavaş Bayt Karşılaştırma** |
| **Başlangıç Yöneticisi** | **Giriş Öğeleri + LaunchAgents + Ölü Servisler** | **Sınırlı / Ayrı Satılan Modül** |
| **Güvenlik & Gizlilik** | **%100 Yerel (Sıfır Telemetri / Buluta Veri Yok)** | **Sürekli Analitik & Telemetri İletişimi** |
| **Fiyatlandırma Modeli** | **Hediye / Tek Seferlik Sahiplik** | **Yıllık 40$ - 90$ Zorunlu Abonelik** |

---

## 🛠️ Ana Yetenekler & Modüller

1. **Akıllı Arınma (Smart Clean):** Geliştirici artıklarını, sistem çöpünü, kırık günlükleri ve geçici önbellekleri tek dokunuşla analiz eder ve güvenle temizler.
2. **Başlangıç & Arka Plan Yöneticisi (Startup Manager):** Mac açıldığında başlayan uygulamaları (Login Items), arka plandaki servisleri (LaunchAgents) tek tıkla açıp kapatır; silinmiş programlardan geriye kalan yetim/ölü kayıtları anında süpürür.
3. **Sistem & Canlı Bellek Röntgeni (Memory & System Turbo):** Apple Silicon birleşik belleği, donanım çekirdeklerini ve en çok RAM tüketen uygulamaları canlı listeler; akıllı tavsiye banner'ı (`[Geç ➔]` döngüsü) ve root gerektirmeyen Darwin VM serbest bırakma döngüsüyle sistemi ferahlatır.
4. **Çift Dosya Avcısı (Duplicate Finder):** Müzik, video, fotoğraf ve belgelerdeki mükerrer dosyaları 3 aşamalı SHA-256 algoritmasıyla sıfır hata payıyla tespit eder; anında küçük resim ve video kareleri sunar.
5. **Hacim Röntgeni (Space Lens):** Diskinizi görsel haritalarla katman katman açarak en çok yer kaplayan devasa klasörleri tespit eder.
6. **Derin Kaldırıcı (Deep App Uninstaller):** Uygulamaları sadece çöpe atmakla kalmaz; `~/Library` içine dağılmış tüm kalıntıları, plisteri ve önbellekleri kökünden siler.
7. **Yazılım Güncelleyici (App Updater):** Sistemdeki Homebrew ve yerel macOS uygulamalarının güncellemelerini tek bir merkezden denetler.
8. **Tarayıcı & Web Gizlilik Kasası:** Safari, Chrome, Arc, Brave, Edge dahil tüm tarayıcılarda IndexedDB, çerez ve önbellek arınması sağlar.
9. **Mimari İnceltici (App Lipo):** Çift mimarili (Universal) uygulamalardaki kullanılmayan Intel/ARM kodlarını ayıklayarak diskte gigabaytlarca alan kazandırır.
10. **Geliştirici Kasası (Developer Vault):** Xcode, CocoaPods, SPM, Node, Docker, Gradle ve Rust derleme çöplerini güvenle arındırır.

---

## 🚀 Kurulum (DMG)

1. **[Ihya.dmg İndir](https://caneser.com/downloads/Ihya.dmg)** veya **[GitHub Releases](https://github.com/skorcu/ihya/releases/latest/download/Ihya.dmg)** üzerinden en güncel resmi sürümü indirin.
2. DMG dosyasını açıp **İhyâ**'yı **Uygulamalar (Applications)** klasörüne sürükleyin.
3. Uygulamayı çalıştırın. macOS Sequoia / Sonoma Gatekeeper onayından pürüzsüzce geçer.

---

## ✨ Sürüm Geçmişi & Yenilikler (Changelog)

### [v1.6.3] — 24 Ekim 2026 (Güncel Sürüm)
- **Başlangıç & Arka Plan Yöneticisi (Startup Manager):**
  - Mac açıldığında başlayan uygulamaları (Login Items - Kâşif, BetterDisplay vb.) ve arka plan servislerini (LaunchAgents - Adobe, Google, Zoom, Brew vb.) tek merkezden listeleyen ve tek tıkla açıp kapatmayı (toggle) sağlayan yeni mimari entegre edildi.
  - Diskten silinmiş veya bozulmuş "Kırık / Ölü Başlangıç Kayıtları"nı (örneğin kaldırılmış Steam vb.) tek tıkla temizleme motoru eklendi.
- **Akıllı Bellek Tavsiyesi Döngüsü (`[Geç ➔]`):**
  - Bellek ekranında en çok RAM tüketen uygulama önerildiğinde (örneğin Antigravity), kapatılmak istenmiyorsa tek tıkla `[Geç ➔]` butonuyla bir sonraki uygulamaya (Xcode, Finder vb.) atlama ve önerileri başa sarma yeteneği getirildi.
  - Kart tasarımı uygulama ikonu, koyu başlık ve kırmızı bellek rozetiyle yeniden tasarlandı.
- **Darwin VM Pressure Serbest Bırakma Motoru:**
  - macOS 14+ ve macOS 15 Sequoia'da root yetkisi olmadan çalışmayan `/usr/sbin/purge` yerine, kullanıcı alanında (Userland) güvenli bellek tahsisi ve `madvise(MADV_FREE)` sinyaliyle inaktif dosya önbelleğini (Inactive Cache) anında düşüren çekirdek baskı döngüsü yazıldı.
  - Bellek kullanım yüzdesi Apple Activity Monitor standardına kalibre edilerek dinamik sıkıştırıcı ve inaktif tamponlar fiziksel aktif bellekten ayrıştırıldı.
- **Sistem & Bellek Hızlı Geçiş Butonu:** Sistem & Bellek sekmesinden tek tıkla Başlangıç Yöneticisi'ne geçiş sağlandı.

### [v1.5.2] — 24 Ekim 2026
- **macOS TCC & Tam Disk Erişimi Köprüsü (FDAChecker):** macOS Sonoma ve Sequoia güvenlik kurallarına tam uyumlu otomatik TCC ön-kaydı, korumalı yol erişim tetiklemesi ve canlı izin algılama mimarisi entegre edildi.
- **Finder Sürükle-Bırak Entegrasyonu:** Sistem Ayarları'nda yeni uygulamaların görünmeme durumuna karşı tek tıkla Finder'da İhyâ'yı seçip pencereye sürükleme köprüsü ve 3 adımlı interaktif görsel rehber eklendi.

### [v1.5.1] — 24 Ekim 2026
- **Tek Tıkla Otomatik Güncelleme Motoru (IhyaUpdateChecker):** Arka plan sürüm kontrolü ve tek tıkla atomik kurulum yeteneği getirildi.
- **15 Günlük Ücretsiz Pro Deneme:** macOS Keychain ile korunan 15 günlük tam Pro deneme sürümü entegre edildi.

---

## 📄 Lisans & Güvenlik

İhyâ, **Sarkaç Adam** tarafından Mac ekosistemine özel olarak geliştirilmiş kapalı kaynaklı (özel mülkiyet / proprietary), resmi Apple Noter güvenlik onaylı ve hediyeli bir arınma ve performans motorudur.  
Tüm fikrî mülkiyet, kaynak kodları ve marka hakları **Sarkaç Adam** ekosistemine aittir.  
Doğal kristal koleksiyonumuzu incelemek ve çalışma masanıza saf enerji katmak için [sarkacadam.com](https://sarkacadam.com) adresini ziyaret edebilirsiniz.
