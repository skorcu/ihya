import Foundation
import IhyaCore

@main
struct IhyaCLI {
    static func main() async {
        let args = CommandLine.arguments
        
        if args.contains("--version") || args.contains("-v") {
            print("İhyâ v1.0.0 Universal 2 (Apple Silicon & Intel) - macOS 14+")
            return
        }
        
        print("======================================================")
        print("  💎 İHYÂ (v1.0.0 Universal 2 - Apple Silicon & Intel)")
        print("  Yeni Nesil macOS Arınma & Canlanma Motoru")
        print("======================================================")
        
        if args.contains("--help") || args.contains("-h") {
            print("\nKullanım:")
            print("  ihya                     : Hızlı sistem taraması yapar ve sonuçları listeler")
            print("  ihya --scan              : Detaylı sistem taraması çalıştırır")
            print("  ihya --clean             : Güvenli arındırmayı icra eder")
            print("  ihya --duplicates <yol>  : Belirtilen klasörde çift dosyaları tarar (Örn: ihya --duplicates ~/Downloads)")
            print("  ihya --apps              : Yüklü uygulamaları ve kütüphane kırıntılarını listeler")
            print("  ihya --orphans           : Silinmiş uygulamalardan kalan yetim kütüphane artıklarını listeler")
            print("  ihya --ghosts            : Hayalet arka plan servislerini listeler")
            print("  ihya --lipo              : Evrensel uygulama mimari fazlalıklarını listeler")
            print("  ihya --updates           : Uygulama güncellemelerini listeler")
            return
        }
        
        if args.contains("--updates") {
            print("\n🔄 Uygulama güncellemeleri denetleniyor...")
            let (updates, totalApps, _) = await AppUpdaterEngine.shared.scanAvailableUpdates()
            print("Toplam Uygulama: \(totalApps) | Bulunan Güncelleme: \(updates.count)")
            for u in updates {
                print("• \(u.appName): Mevcut v\(u.currentVersion) -> Yeni v\(u.latestVersion) [\(u.source.rawValue)]")
            }
            return
        }
        
        // 1. Çift Dosya Taraması
        if let dupIndex = args.firstIndex(of: "--duplicates") {
            var targetDir = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
            if dupIndex + 1 < args.count {
                targetDir = (args[dupIndex + 1] as NSString).expandingTildeInPath
            }
            print("\n🔍 '\(targetDir)' dizininde çift dosyalar taranıyor...")
            let groups = await DuplicateFinderEngine.shared.scanDuplicates(in: targetDir)
            if groups.isEmpty {
                print("✅ Belirtilen dizinde çift dosya bulunamadı.")
            } else {
                let totalReclaimable = groups.reduce(0) { $0 + $1.reclaimableSize }
                print("🎯 \(groups.count) ikiz dosya grubu bulundu! Toplam kazanılabilir: \(ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file))\n")
                for (i, g) in groups.prefix(15).enumerated() {
                    print("[\(i + 1)] Boyut: \(g.formattedSize) • \(g.files.count) Kopya")
                    for f in g.files {
                        print("    \(f.isOriginal ? "🟢 [Orijinal]" : "🔴 [Kopya]   ") \(f.name) (\(f.path))")
                    }
                }
            }
            return
        }
        
        // 2. Yüklü Uygulamalar ve Derin Kırıntılar
        if args.contains("--apps") {
            print("\n📦 Yüklü uygulamalar ve kütüphane kırıntıları taranıyor...")
            let (apps, _) = await AppUninstallerEngine.shared.scanInstalledApps()
            print("🎯 \(apps.count) adet uygulama tespit edildi:\n")
            for app in apps.prefix(20) {
                print("• \(app.name) (v\(app.version)) - Toplam: \(app.formattedTotalSize)")
                print("  Paket: \(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file)) | Kırıntılar: \(app.remnants.count) adet (\(ByteCountFormatter.string(fromByteCount: app.remnants.reduce(0){$0+$1.size}, countStyle: .file)))")
            }
            return
        }
        
        // 3. Yetim Kütüphane Artıkları
        if args.contains("--orphans") {
            print("\n🏚️ Yetim uygulama kütüphane artıkları taranıyor...")
            let (_, orphans) = await AppUninstallerEngine.shared.scanInstalledApps()
            if orphans.isEmpty {
                print("✅ Sistemde sahipsiz yetim kalıntı bulunamadı.")
            } else {
                let totalOrphanSize = orphans.reduce(0) { $0 + $1.totalSize }
                print("🎯 \(orphans.count) adet yetim artık grubu bulundu! Toplam: \(ByteCountFormatter.string(fromByteCount: totalOrphanSize, countStyle: .file))\n")
                for o in orphans.prefix(15) {
                    print("• \(o.name): \(o.formattedSize) (\(o.items.count) klasör/dosya)")
                }
            }
            return
        }
        
        // 4. Hayalet Servis Taraması
        if args.contains("--ghosts") {
            print("\n👻 Hayalet servisler taranıyor...")
            let ghosts = await GhostDaemonEngine.shared.scanGhostDaemons()
            if ghosts.isEmpty {
                print("✅ Sistemde hiçbir hayalet veya ölü servis bulunamadı.")
            } else {
                print("⚠️  \(ghosts.count) adet ölü arka plan servisi tespit edildi:")
                for g in ghosts {
                    print("• [\(g.isUserAgent ? "Kullanıcı" : "Sistem")] \(g.label)")
                    print("  Plist : \(g.plistPath)")
                    print("  Hedef : \(g.missingBinaryPath) (Eksik/Silinmiş!)")
                }
            }
            return
        }
        
        // 3. Uygulama İnceltici (Lipo)
        if args.contains("--lipo") {
            print("\n✂️ Evrensel uygulamalar ve mimari kodları inceleniyor...")
            let items = await AppLipoEngine.shared.scanUniversalApps()
            if items.isEmpty {
                print("✅ Budanabilecek evrensel uygulama bulunamadı.")
            } else {
                let totalReclaim = items.reduce(0) { $0 + $1.reclaimableSize }
                print("📦 \(items.count) uygulama budanabilir. Kazanılabilir alan: \(ByteCountFormatter.string(fromByteCount: totalReclaim, countStyle: .file))\n")
                for it in items {
                    print("• \(it.appName): Mevcut \(ByteCountFormatter.string(fromByteCount: it.currentSize, countStyle: .file)) -> Kazanılacak: +\(it.formattedReclaimable)")
                }
            }
            return
        }
        
        // 4. Varsayılan / Standart Sistem Taraması
        let engine = CleanerEngine.shared
        print("\n⏳ Sistem taranıyor...")
        await engine.runFullScan()
        
        let totalSize = ByteCountFormatter.string(fromByteCount: engine.totalReclaimableBytes, countStyle: .file)
        print("\n✅ Tarama Tamamlandı!")
        print("------------------------------------------------------")
        for cat in engine.categories {
            print("• \(cat.category.rawValue.uppercased()): \(cat.formattedSize) (\(cat.items.count) öğe)")
        }
        if !engine.ghostDaemons.isEmpty {
            print("• HAYALET SERVİSLER: \(engine.ghostDaemons.count) ölü arka plan servisi tespit edildi.")
        }
        if !engine.lipoCandidates.isEmpty {
            let lipoSize = engine.lipoCandidates.reduce(0) { $0 + $1.reclaimableSize }
            print("• UYGULAMA İNCELTİCİ: \(ByteCountFormatter.string(fromByteCount: lipoSize, countStyle: .file)) kazanılabilir.")
        }
        print("------------------------------------------------------")
        print("🌟 Toplam Kazanılabilir Alan: \(totalSize)\n")
        
        if args.contains("--clean") {
            print("🧹 Arındırma işlemi başlatılıyor...")
            let freed = await engine.performClean()
            let freedStr = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
            print("🎉 Tebrikler! \(freedStr) disk alanı başarıyla geri kazanıldı.")
        }
    }
}
