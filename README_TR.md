# 💎 İhyâ (Mac) — Yeni Nesil Saf macOS Arınma & Canlanma Motoru

<div align="center">
  <img src="https://caneser.com/images/ihya-logo.webp" width="128" height="128" alt="İhyâ macOS Logo" />
  <br />
  <h2>Işık Hızında, %100 Yerel ve Gizlilik Odaklı macOS Sistem Arınma & Hız Mimarisi</h2>
  <p><b>Apple Silicon (M1/M2/M3/M4) ve Intel (x86_64) Universal 2 Mimarisiyle Sıfır Tavizli Saf Performans</b></p>
  <p>
    <a href="README.md"><b>English</b></a> • 
    <a href="README_TR.md"><b>🇹🇷 Türkçe</b></a>
  </p>
  <p>
    <a href="https://caneser.com/downloads/Ihya.dmg"><img src="https://img.shields.io/badge/DMG_İndir-v1.8.0_Universal_2-10B981?style=for-the-badge&logo=apple&logoColor=white" /></a>
    <img src="https://img.shields.io/badge/Apple_Noter-Resmi_Onaylı_✓-0284C7?style=for-the-badge&logo=apple" />
  </p>
  <p>
    <img src="https://img.shields.io/badge/Platform-macOS_14+_Sonoma_|_Sequoia-000000?style=flat-square&logo=apple&logoColor=white" />
    <img src="https://img.shields.io/badge/Mimari-Universal_2_(arm64_+_x86__64)-8B5CF6?style=flat-square" />
    <img src="https://img.shields.io/badge/Swift-6.0_|_SwiftUI-F05138?style=flat-square&logo=swift&logoColor=white" />
    <img src="https://img.shields.io/badge/Gizlilik-%100_Yerel_•_Sıfır_Telemetri-10B981?style=flat-square" />
    <a href="https://github.com/skorcu/kasif"><img src="https://img.shields.io/badge/Kardeş_Uygulama-Kâşif_(APFS_Arama)-0284C7?style=flat-square&logo=apple&logoColor=white" /></a>
    <img src="https://img.shields.io/badge/Lisans-Proprietary_(Telif_Korumalı)-blue?style=flat-square" />
  </p>
</div>

---

## 🌿 Sarkaç Adam'dan Mac Topluluğuna Bir Arınma Hediyesi

> *"Zihinsel berraklık ve doğal denge için kadim doğal kristallerin huzurunu ararken, her gün saatlerimizi geçirdiğimiz çalışma alanımız olan Mac'imizin de arınmış, hafif ve pürüzsüz olması gerektiğine inanıyoruz.*  
> *Sarkaç Adam olarak; geleneksel abonelik tuzaklarına ve sistemi yoran hantal araçlara inat, en saf Swift mühendisliğiyle geliştirdiğimiz **İhyâ**'yı tüm Mac kullanıcılarına **karşılıksız bir hediye** olarak takdim ediyoruz.*  
> *Mac'iniz ilk günkü saf hızına kavuşurken, sizleri de çalışma masanıza sükûnet ve denge katacak doğal kristallerimizle tanışmaya davet ediyoruz."*

---

## ⚡ Neden İhyâ? (Temel Farklar ve Karşılaştırma)

Geleneksel Mac temizleyicileri genellikle arka planda sürekli çalışan ağır servislerle sistemi yorar, aylık abonelikler talep eder ve yüzlerce megabaytlık yer kaplar. **İhyâ**, macOS'un en modern yerel kütüphaneleriyle (SwiftUI, Combine, Darwin Kernel APIs, AppKit) sıfırdan geliştirilmiştir.

*Test Ortamı: Apple M-Serisi Apple Silicon & APFS SSD • 1.200.000 Dosya Havuzu*

| Metrik & Standart | 💎 **İhyâ (v1.7.0 Universal 2)** | 📦 **Geleneksel Abonelikli Araçlar** |
| :--- | :--- | :--- |
| **Uygulama İkili Boyutu** | **8.3 MB** (Saf Swift Universal 2) | **180 MB – 260 MB** (Ağır Frameworkler) |
| **Arka Planda RAM Tüketimi** | **0.0 MB** (Beklemede Servis Çalıştırmaz) | **180 MB – 350 MB** (24/7 Arka Plan Daemons) |
| **Tam Sistem Tarama Hızı** | **~4 - 8 Saniye** (Çok Çekirdekli Eşzamanlı) | **45 - 90 Saniye** (Tek Çekirdek Kısıtı) |
| **Çakışan Araç Nötralizasyonu**| **Dahili (Arka Plan Kancalarını Temizler)**| **Yok / Çakışma Yaratır** |
| **Çift Dosya Analizi** | **3 Aşamalı SHA-256** (Ön-hash + Tam Hash) | **Yavaş Bayt Karşılaştırma** |
| **Başlangıç Yöneticisi** | **Giriş Öğeleri + LaunchAgents + Ölü Servisler** | **Sınırlı / Ayrı Satılan Modül** |
| **Güvenlik & Gizlilik** | **%100 Yerel (Sıfır Telemetri / Buluta Veri Yok)** | **Sürekli Analitik & Telemetri İletişimi** |
| **Fiyatlandırma Modeli** | **Hediye / Tek Seferlik Sahiplik** | **Yıllık 40$ - 90$ Zorunlu Abonelik** |

---

## 🛠️ Ana Yetenekler & Modüller

1. **Akıllı Arınma (Smart Clean):** Geliştirici artıklarını, sistem çöpünü, kırık günlükleri ve geçici önbellekleri tek dokunuşla analiz eder ve güvenle temizler.
2. **Çakışan Araç Dedektörü & Nötralizasyonu:** Sistemde kurulu olan ve Çöp Sepeti kancalarıyla kilitlenme yaratan harici araçları (AppCleaner, CleanMyMac vb.) açılışta tespit eder, daimonlarını ve arka plan servislerini tek tıkla arındırır.
3. **Başlangıç & Arka Plan Yöneticisi (Startup Manager):** Mac açıldığında başlayan uygulamaları (Login Items), arka plandaki servisleri (LaunchAgents) tek tıkla açıp kapatır; silinmiş programlardan geriye kalan yetim/ölü kayıtları anında süpürür.
4. **Sistem & Canlı Bellek Röntgeni (Memory & System Turbo):** Apple Silicon birleşik belleği, donanım çekirdeklerini ve en çok RAM tüketen uygulamaları canlı listeler; akıllı tavsiye banner'ı (`[Geç ➔]` döngüsü) ve root gerektirmeyen Darwin VM serbest bırakma döngüsüyle sistemi ferahlatır.
5. **Çift Dosya Avcısı (Duplicate Finder):** Müzik, video, fotoğraf ve belgelerdeki mükerrer dosyaları 3 aşamalı SHA-256 algoritmasıyla sıfır hata payıyla tespit eder; anında küçük resim ve video kareleri sunar.
6. **Hacim Röntgeni (Space Lens):** Diskinizi görsel haritalarla katman katman açarak en çok yer kaplayan devasa klasörleri tespit eder.
7. **Derin Kaldırıcı (Deep App Uninstaller):** Uygulamaları sadece çöpe atmakla kalmaz; `~/Library` içine dağılmış tüm kalıntıları, plisteri ve sandbox konteynerlerini kökünden siler.
8. **Yazılım Güncelleyici (App Updater):** Sistemdeki Homebrew ve yerel macOS uygulamalarının güncellemelerini tek bir merkezden denetler.
9. **Tarayıcı & Web Gizlilik Kasası:** Safari, Chrome, Arc, Brave, Edge dahil tüm tarayıcılarda IndexedDB, çerez ve önbellek arınması sağlar.
10. **Mimari İnceltici (App Lipo):** Çift mimarili (Universal) uygulamalardaki kullanılmayan Intel/ARM kodlarını ayıklayarak diskte gigabaytlarca alan kazandırır.
11. **Geliştirici Kasası (Developer Vault):** Xcode, CocoaPods, SPM, Node, Docker, Gradle ve Rust derleme çöplerini güvenle arındırır.

---

## 🚀 Kurulum (DMG)

1. **[Ihya.dmg İndir](https://caneser.com/downloads/Ihya.dmg)** üzerinden en güncel resmi sürümü indirin.
2. DMG dosyasını açıp **İhyâ**'yı **Uygulamalar (Applications)** klasörüne sürükleyin.
3. Uygulamayı çalıştırın. macOS Sequoia / Sonoma Gatekeeper onayından pürüzsüzce geçer.

---

## ✨ Sürüm Geçmişi & Yenilikler (Changelog)

### [v1.8.0] — 26 Ekim 2026 (Apple Noter Onaylı En Güncel Sürüm)
- **Kurulum Paketleri & DMG Röntgeni Modülü:**
  - İndirilenler, Masaüstü ve sistem depolarındaki tüm `.dmg`, `.pkg`, `.iso` ve açık disk imajlarını derinlemesine tarama yeteneği.
  - **4 Kademeli Akıllı Durum Matrisi:** Yüklü uygulamalara ait paketleri ve eski sürümleri otomatik seçili (güvenle silinebilir), henüz kurulmamış paketleri ise korumalı (seçimsiz) listeleme.
  - **Tek Tıkla Kur & Çöpe At:** Yüklü olmayan DMG paketlerini tek dokunuşla `/Applications`'a kurup imajı otomatik Çöp Sepeti'ne gönderme inovasyonu.
  - **Açık Kalan Sürücü Yönetimi:** Masaüstünde unutulmuş mounted disk imajlarını tek tıkla unmount edip arındırma.
- **Apple Noter Sertifikasyon Onayı:**
  - Apple Notary Service tarafından onaylanıp resmi mühürlü DMG olarak paketlendi.

### [v1.7.0] — 25 Ekim 2026
- **Çakışan Temizlik Araçları Algılama ve Arındırma:**
  - Sistemde çalışan harici araçların (AppCleaner, CleanMyMac vb.) ve arka plan daimonlarının açılışta tespit edilmesi.
  - Tek tıkla derin kırıntılarıyla ve `launchd` servisleriyle birlikte arındırılması desteği.
- **Konteyner ve Sandbox Kilit Desteği:**
  - ACL kilitli grup konteynerleri ve sandbox artıklarında kesintisiz temizlik garantisi.
- **Apple Noter Sertifikasyon Onayı:**
  - Apple Notary Service tarafından onaylanıp resmi mühürlü DMG olarak paketlendi.

---

## 🤝 Kusursuz İkili: Kâşif ile Işık Hızında APFS Arama Deneyimi 🧭

İhyâ ile Mac'inizi gigabaytlarca gereksiz çöpten ve arka plan yükünden arındırıp ilk günkü saf hızına kavuşturduktan sonra, aradığınız herhangi bir dosyaya milisaniyeler içinde ulaşmak için **[Kâşif](https://github.com/skorcu/kasif)** ile tanışın!

- ⚡ **0.001s APFS Hızı:** 5.000.000+ dosyayı milisaniyeler içinde tarar; harici 8TB SSD'lerde bile anında sonuç listeler.
- 💬 **WhatsApp, Telegram & iMessage Derin Arama:** Yerel mesaj arşivlerini tarayarak sohbetleri ve belgeleri anında bulur.
- 📬 **Apple Mail & Outlook:** Tüm e-postalarda anında tam metin arama.
- 🔋 **Sıfır Pil & ~20 MB RAM:** Arka planda asla ağır servis veya fan çalıştırmaz (%0.0 CPU).

👉 **[Kâşif'i GitHub'da İnceleyin & İndirin ➔](https://github.com/skorcu/kasif)**

---

## 📄 Lisans & Güvenlik

İhyâ, **Sarkaç Adam** tarafından Mac ekosistemine özel olarak geliştirilmiş kapalı kaynaklı (özel mülkiyet / proprietary), resmi Apple Noter güvenlik onaylı ve hediyeli bir arınma ve performans motorudur.  
Tüm fikrî mülkiyet, kaynak kodları ve marka hakları **Sarkaç Adam** ekosistemine aittir.  
Doğal kristal koleksiyonumuzu incelemek ve çalışma masanıza saf enerji katmak için [sarkacadam.com](https://sarkacadam.com) adresini ziyaret edebilirsiniz.
