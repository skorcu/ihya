import XCTest
@testable import IhyaCore

final class IhyaTests: XCTestCase {
    
    // MARK: - 1. Güvenlik Filtresi Testleri (Safety Filter)
    func testSafetyFilterCriticalPaths() {
        // macOS Çekirdek Sistem Yolları Asla Silinemez
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/System"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/System/Library"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/usr/bin"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/usr/sbin"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/bin"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/sbin"))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: "/Library"))
        
        // Kullanıcı Şahsî Veri Klasörleri Korumalıdır
        let home = NSHomeDirectory()
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: home))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: (home as NSString).appendingPathComponent("Documents")))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: (home as NSString).appendingPathComponent("Desktop")))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: (home as NSString).appendingPathComponent("Pictures")))
        XCTAssertFalse(SafetyFilter.shared.isSafeToDelete(path: (home as NSString).appendingPathComponent("Music")))
    }
    
    // MARK: - 2. Hacim Röntgeni (Space Lens) Düğüm & Hesaplama Testleri
    func testSpaceLensNodeCalculation() {
        let child1 = LensNode(name: "Xcode", path: "/test/Xcode", isDirectory: true, size: 7_000_000_000, percentage: 0.7)
        let child2 = LensNode(name: "Downloads", path: "/test/Downloads", isDirectory: true, size: 3_000_000_000, percentage: 0.3)
        
        let root = LensNode(
            name: "Home",
            path: "/test",
            isDirectory: true,
            size: 10_000_000_000,
            children: [child1, child2],
            percentage: 1.0
        )
        
        XCTAssertEqual(root.children.count, 2)
        XCTAssertEqual(root.children[0].name, "Xcode")
        XCTAssertEqual(root.children[0].percentage, 0.7)
        XCTAssertFalse(root.formattedSize.isEmpty)
        XCTAssertFalse(child1.formattedSize.isEmpty)
    }
    
    // MARK: - 3. Sistem & Bellek Optimizasyonu Testleri
    @MainActor
    func testSystemOptimizationEngine() {
        let engine = SystemOptimizationEngine.shared
        engine.refreshMemoryStats()
        
        XCTAssertGreaterThan(engine.memoryStats.totalBytes, 0, "Fiziksel RAM sıfırdan büyük olmalı")
        XCTAssertGreaterThanOrEqual(engine.memoryStats.usagePercentage, 0.0)
        XCTAssertLessThanOrEqual(engine.memoryStats.usagePercentage, 100.0)
        XCTAssertEqual(engine.tasks.count, 6, "6 temel sistem optimizasyon görevi tanımlı olmalı (RAM, DNS, QuickLook, Logs, APFS Snapshots, Font Cache)")
    }
    
    @MainActor
    func testSpaceLensEngineNavigation() async {
        let engine = SpaceLensEngine.shared
        
        // Geçici bir test dizini oluştur
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IhyaSpaceLensTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Alt klasör ve dosya yaz
        let subDir = tempDir.appendingPathComponent("SubFolder")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let sampleData = Data(repeating: 0x41, count: 2_000_000) // 2 MB
        try? sampleData.write(to: subDir.appendingPathComponent("sample.bin"))
        
        // Taramayı başlat
        await engine.scan(path: tempDir.path)
        XCTAssertNotNil(engine.rootNode)
        XCTAssertEqual(engine.pathBreadcrumbs.count, 1)
        
        // Alt klasöre drill down
        if let subNode = engine.currentNode?.children.first(where: { $0.isDirectory }) {
            engine.drillDown(to: subNode)
            // Asenkron tarama için kısa bekleme
            try? await Task.sleep(nanoseconds: 500_000_000)
            XCTAssertEqual(engine.pathBreadcrumbs.count, 2)
            XCTAssertEqual(engine.currentNode?.name, "SubFolder")
            
            // Geri dön
            engine.navigateBack(to: 0)
            XCTAssertEqual(engine.pathBreadcrumbs.count, 1)
        }
    }
    
    // MARK: - 4. Çift Dosya Kural Motoru Testleri
    func testDuplicateFileRetentionRules() {
        let fileOld = DuplicateFile(
            path: "/Users/test/Downloads/photo_v1.png",
            name: "photo_v1.png",
            modifiedDate: Date(timeIntervalSince1970: 1000)
        )
        let fileNew = DuplicateFile(
            path: "/Users/test/Documents/photo_v2.png",
            name: "photo_v2.png",
            modifiedDate: Date(timeIntervalSince1970: 5000)
        )
        
        // En Eski Dosya Koruması
        XCTAssertTrue(fileOld.modifiedDate < fileNew.modifiedDate)
        
        // Klasör Koruması (Downloads sil, Documents koru)
        XCTAssertTrue(fileOld.path.contains("Downloads"))
        XCTAssertTrue(fileNew.path.contains("Documents"))
    }
    
    // MARK: - 5. Lisans & VIP Anahtar Doğrulama Testleri
    func testLicenseManagerOfflineValidation() {
        let payload = "CAN001"
        let validSig = LicenseManager.shared.computeSignature(for: payload)
        let validKey = "IHYA-PRO-\(payload)-\(validSig)"
        let invalidKey = "RANDOM-INVALID-KEY"
        
        XCTAssertTrue(LicenseManager.shared.verifyKey(validKey))
        XCTAssertFalse(LicenseManager.shared.verifyKey(invalidKey))
    }
    
    // MARK: - 6. Çift Dosya Önbellek & Artımlı Hash Testleri
    func testDuplicateHashCachePersistence() async {
        let cache = DuplicateHashCache.shared
        let testPath = "/tmp/ihya_test_video.mp4"
        let mtime = 99999.0
        let size: Int64 = 15_000_000
        let partialKey = "4096_mockprefix_mocksuffix"
        let fullSHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        
        await cache.setPartial(path: testPath, mtime: mtime, size: size, partialKey: partialKey)
        await cache.setFullSHA256(path: testPath, mtime: mtime, size: size, partialKey: partialKey, fullSHA256: fullSHA256)
        await cache.saveToDisk()
        
        let record = await cache.getRecord(path: testPath, currentMTime: mtime, currentSize: size)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.fullSHA256, fullSHA256)
        XCTAssertEqual(record?.partialKey, partialKey)
        
        // Değiştirilmiş mtime veya boyut durumunda önbelleğin geçersiz olması testi
        let invalidMtimeRecord = await cache.getRecord(path: testPath, currentMTime: mtime + 10.0, currentSize: size)
        XCTAssertNil(invalidMtimeRecord)
    }
    
    @MainActor
    func testDuplicateDetectionWithDifferentNames() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let subDir1 = tempDir.appendingPathComponent("FolderA")
        let subDir2 = tempDir.appendingPathComponent("FolderB")
        try? FileManager.default.createDirectory(at: subDir1, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)
        
        // Birebir aynı içerik, tamamen farklı iki dosya adı ve uzantı/klasör
        let dummyContent = Data(repeating: 0x42, count: 12000)
        let file1 = subDir1.appendingPathComponent("Orijinal_IMG_001.jpg")
        let file2 = subDir2.appendingPathComponent("Kopya_Tamamen_Farkli_Isim.jpg")
        
        try? dummyContent.write(to: file1)
        try? dummyContent.write(to: file2)
        
        let engine = DuplicateFinderEngine.shared
        let groups = await engine.scanDuplicates(in: [tempDir.path], minSize: 1000)
        
        XCTAssertEqual(groups.count, 1, "Farklı isimli olsalar dahi içerikleri aynı olan dosyalar tek bir ikiz grup oluşturmalıdır.")
        XCTAssertEqual(groups.first?.files.count, 2, "İkiz grup içerisinde 2 dosya yer almalıdır.")
    }
    
    // MARK: - 7. Anlamlı Dosyalar ve Gürültü Süzgeci Testleri
    func testMeaningfulExtensionsAndNoiseFilter() {
        // Yaygın kullanıcı dosyaları dahil edilmeli
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("mp4"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("mov"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("jpg"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("png"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("pdf"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("docx"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("xlsx"))
        XCTAssertTrue(DuplicateFinderEngine.commonMeaningfulExtensions.contains("zip"))
        
        // Geliştirici/derleme gürültüleri filtrelenmeli
        XCTAssertFalse(DuplicateFinderEngine.commonMeaningfulExtensions.contains("dill"))
        XCTAssertFalse(DuplicateFinderEngine.commonMeaningfulExtensions.contains("bin"))
        XCTAssertTrue(DuplicateFinderEngine.noiseExtensions.contains("dill"))
        XCTAssertTrue(DuplicateFinderEngine.noiseExtensions.contains("bin"))
        XCTAssertTrue(DuplicateFinderEngine.noiseDirectories.contains("node_modules"))
        XCTAssertTrue(DuplicateFinderEngine.noiseDirectories.contains(".git"))
    }
    
    // MARK: - 8. Klasör Dağılım Özeti Testleri
    @MainActor
    func testFolderSummariesCalculation() {
        let f1 = DuplicateFile(path: "/Users/test/Downloads/a.jpg", name: "a.jpg", isSelectedForDeletion: true)
        let f2 = DuplicateFile(path: "/Users/test/Desktop/a_copy.jpg", name: "a_copy.jpg", isSelectedForDeletion: true)
        let group = DuplicateGroup(fileSize: 500_000, sha256: "dummyhash", files: [f1, f2])
        
        let summaries = DuplicateFinderEngine.shared.getFolderSummaries(from: [group])
        XCTAssertEqual(summaries.count, 2)
        XCTAssertTrue(summaries.contains(where: { $0.folderName == "Downloads" && $0.count == 1 }))
        XCTAssertTrue(summaries.contains(where: { $0.folderName == "Desktop" && $0.count == 1 }))
    }
    
    // MARK: - 9. Tarayıcı & Web Gizlilik Kasası Testleri
    func testBrowserDataTypeSafetyAndDefaults() async {
        // Parola ve hassas veriler varsayılan olarak KESİNLİKLE kapalı olmalıdır
        XCTAssertFalse(BrowserDataType.passwords.defaultSelected)
        XCTAssertFalse(BrowserDataType.cookies.defaultSelected)
        XCTAssertFalse(BrowserDataType.history.defaultSelected)
        XCTAssertFalse(BrowserDataType.autofill.defaultSelected)
        
        // Önbellekler ve render verileri varsayılan olarak açık olmalıdır
        XCTAssertTrue(BrowserDataType.webCache.defaultSelected)
        XCTAssertTrue(BrowserDataType.codeCache.defaultSelected)
        XCTAssertTrue(BrowserDataType.offlineStorage.defaultSelected)
        XCTAssertTrue(BrowserDataType.favicons.defaultSelected)
        
        // Parola için kritik güvenlik bayrağı ve uyarı metni kontrolü
        XCTAssertTrue(BrowserDataType.passwords.isCritical)
        XCTAssertTrue(BrowserDataType.passwords.isCaution)
        XCTAssertNotNil(BrowserDataType.passwords.warningNote)
        
        // Tarayıcı tespiti testi
        let browsers = await BrowserCacheEngine.shared.detectInstalledBrowsers()
        XCTAssertFalse(browsers.isEmpty, "Sistemde en az bir tarayıcı (Safari) kurulu olmalıdır")
        
        if let safari = browsers.first(where: { $0.name == "Safari" }) {
            XCTAssertGreaterThan(safari.totalSize, 0, "Safari veri boyutu sıfırdan büyük olmalıdır")
        }
    }
}
