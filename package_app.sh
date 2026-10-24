#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "============================================="
echo "  İHYÂ - Apple Universal 2 Derleme & Paketleme"
echo "  (Apple Silicon arm64 + Intel x86_64 Destekli)"
echo "============================================="

# 1. Derleme Klasörleri
RELEASE_DIR="$DIR/.build/out/Products/Release"
mkdir -p "$RELEASE_DIR"
mkdir -p "$DIR/.build/arch_bins"

echo "1/5 [ARM64] Apple Silicon derleniyor..."
swift build -c release --arch arm64
cp "$RELEASE_DIR/IhyaApp" "$DIR/.build/arch_bins/IhyaApp_arm64"
cp "$RELEASE_DIR/ihya" "$DIR/.build/arch_bins/ihya_arm64"

echo "2/5 [x86_64] Intel Core/Xeon derleniyor..."
swift build -c release --arch x86_64
cp "$RELEASE_DIR/IhyaApp" "$DIR/.build/arch_bins/IhyaApp_x86_64"
cp "$RELEASE_DIR/ihya" "$DIR/.build/arch_bins/ihya_x86_64"

# 2. Universal 2 Birleştirme (lipo)
echo "3/5 Universal 2 ikili dosyaları birleştiriliyor (lipo)..."
lipo -create \
  "$DIR/.build/arch_bins/IhyaApp_arm64" \
  "$DIR/.build/arch_bins/IhyaApp_x86_64" \
  -output "$RELEASE_DIR/IhyaApp"

lipo -create \
  "$DIR/.build/arch_bins/ihya_arm64" \
  "$DIR/.build/arch_bins/ihya_x86_64" \
  -output "$RELEASE_DIR/ihya"

echo "Doğrulanan Mimariler:"
lipo -info "$RELEASE_DIR/IhyaApp"
lipo -info "$RELEASE_DIR/ihya"

# 3. .app Paketi Tanzimi
echo "4/5 İhyâ.app paketi tanzim ediliyor..."
APP_DIR="$DIR/dist/İhyâ.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$RELEASE_DIR/IhyaApp" "$APP_DIR/Contents/MacOS/IhyaApp"
chmod +x "$APP_DIR/Contents/MacOS/IhyaApp"

if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
if [ -f "$DIR/Resources/icon_1024.png" ]; then
    cp "$DIR/Resources/icon_1024.png" "$APP_DIR/Contents/Resources/icon_1024.png"
fi

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>tr</string>
    <key>CFBundleExecutable</key>
    <string>IhyaApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.caneser.ihya</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>İhyâ</string>
    <key>CFBundleDisplayName</key>
    <string>İhyâ</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.0</string>
    <key>CFBundleVersion</key>
    <string>1.4.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>İhyâ, İndirilenler klasörünüzdeki büyük ve çift dosyaları tespit edip disk alanı açabilmek için erişim sağlar.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>İhyâ, Belgeler klasörünüzdeki büyük ve eski dosyaları tarayıp yer açabilmeniz için erişim sağlar.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>İhyâ, Masaüstündeki büyük ve eski dosyaları tarayabilmek için erişim sağlar.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>İhyâ, harici disklerdeki çift dosyaları taramak ve büyük dosyaları güvenle harici diske arşivleyebilmek için erişim sağlar.</string>
</dict>
</plist>
EOF

# 4. Kod İmzalama
echo "5/6 Apple Developer ID Sertifikası ile imzalanıyor..."
DEV_ID=$(security find-identity -p codesigning -v | grep "Developer ID Application:" | grep -v "REVOKED" | head -n 1 | awk '{print $2}')

if [ -z "$DEV_ID" ]; then
    echo "Developer ID bulunamadı, Apple Development deneniyor..."
    DEV_ID=$(security find-identity -p codesigning -v | grep "Apple Development:" | grep -v "REVOKED" | head -n 1 | awk '{print $2}')
fi

if [ -n "$DEV_ID" ]; then
    echo "Kullanılan Apple Sertifikası: $DEV_ID"
    # Önce iç ikili dosyaları Hardened Runtime ile imzala
    if [ -f "$APP_DIR/Contents/MacOS/ihya" ]; then
        codesign --force --options runtime --timestamp --sign "$DEV_ID" --entitlements "$DIR/Entitlements.plist" --identifier "com.caneser.ihya.cli" "$APP_DIR/Contents/MacOS/ihya"
    fi
    codesign --force --options runtime --timestamp --sign "$DEV_ID" --entitlements "$DIR/Entitlements.plist" --identifier "com.caneser.ihya" "$APP_DIR"
else
    echo "Yerel kararlı ad-hoc imza uygulanıyor..."
    codesign --force --deep --sign - --requirements '=designated => identifier "com.caneser.ihya"' --entitlements "$DIR/Entitlements.plist" --identifier "com.caneser.ihya" "$APP_DIR"
fi

# 5. Yerel Kurulum (TCC İzinlerini ve Bundle Kimliğini Koruyan Atomik Güncelleme)
echo "Yerel sisteme kuruluyor: /Applications/İhyâ.app"
killall IhyaApp 2>/dev/null || true
sleep 0.3
ditto "$APP_DIR" "/Applications/İhyâ.app"
touch "/Applications/İhyâ.app"

# Spotlight ve LaunchServices'ın dist/ klasörünü indekslemesini engelle
touch "$DIR/dist/.metadata_never_index"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP_DIR" 2>/dev/null || true

mkdir -p "$HOME/.local/bin"
cp "$RELEASE_DIR/ihya" "$HOME/.local/bin/ihya"
chmod +x "$HOME/.local/bin/ihya"

# 6. DMG Paketleme (Spotlight'ın geçici dizini indekslemesini önlemek için .noindex kullanılır)
echo "Son kullanıcı için DMG paketi üretiliyor..."
DMG_STAGE="$DIR/dist/build.noindex/dmg_stage"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"

cp -R "$APP_DIR" "$DMG_STAGE/İhyâ.app"
ln -s /Applications "$DMG_STAGE/Uygulamalar (Applications)"

cat << 'EOF' > "$DMG_STAGE/1-Tıkla İhyâ'yı Kur ve Başlat.command"
#!/bin/bash
clear
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "============================================="
echo "  İHYÂ - Otomatik Kurulum & Başlatma"
echo "============================================="
echo ""
echo "📦 1/3 Eski İhyâ sürümü kapatılıyor..."
killall IhyaApp 2>/dev/null || true
sleep 0.5

echo "📁 2/3 İhyâ uygulaması /Applications klasörüne kuruluyor..."
rm -rf "/Applications/İhyâ.app"
cp -R "$DIR/İhyâ.app" "/Applications/İhyâ.app"

echo "🔓 3/3 macOS güvenlik ve karantina onayları tamamlanıyor..."
xattr -cr "/Applications/İhyâ.app" 2>/dev/null || true
xattr -rd com.apple.quarantine "/Applications/İhyâ.app" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/İhyâ.app" 2>/dev/null || true

echo ""
echo "✅ Kurulum başarıyla tamamlandı!"
echo "🚀 İhyâ başlatılıyor..."
sleep 0.5
open -a "/Applications/İhyâ.app"
exit 0
EOF
chmod +x "$DMG_STAGE/1-Tıkla İhyâ'yı Kur ve Başlat.command"

DMG_OUTPUT="$DIR/dist/Ihya.dmg"
rm -f "$DMG_OUTPUT"

hdiutil create -volname "İhyâ" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUTPUT"
rm -rf "$DIR/dist/build.noindex"

# 7. Apple Notarization & Stapling
if [ -n "$DEV_ID" ]; then
    echo "6/6 Apple Noter Onayı (Notarization) alınıyor..."
    codesign --force --sign "$DEV_ID" --timestamp "$DMG_OUTPUT"
    
    echo "Apple sunucularına iletiliyor (notarytool)..."
    if xcrun notarytool submit "$DMG_OUTPUT" --keychain-profile "KASIF_NOTARY" --wait; then
        echo "Apple resmi noter onayını damgalıyor (stapling)..."
        sleep 5
        xcrun stapler staple "$DMG_OUTPUT"
        xcrun stapler staple "/Applications/İhyâ.app" 2>/dev/null || true
        echo "Resmi Apple Noter Onayı Başarıyla Tamamlandı!"
    else
        echo "Uyarı: Noter onayı alınamadı, ancak paket Developer ID ile imzalandı."
    fi
fi

# Dist içindeki .app paketini LaunchServices'tan kesin kaldır (sadece /Applications kalsın)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP_DIR" 2>/dev/null || true
rm -rf "$APP_DIR"

WEB_DOWNLOAD_DIR="/Users/can/Projeler/Yeni Sunucu/caneser.com/public/downloads"
if [ -d "$WEB_DOWNLOAD_DIR" ]; then
    cp "$DMG_OUTPUT" "$WEB_DOWNLOAD_DIR/Ihya.dmg"
    echo "Web dağıtım klasörüne kopyalandı: $WEB_DOWNLOAD_DIR/Ihya.dmg"
fi

WEB_OUT_DIR="/Users/can/Projeler/Yeni Sunucu/caneser.com/out/downloads"
if [ -d "$WEB_OUT_DIR" ]; then
    cp "$DMG_OUTPUT" "$WEB_OUT_DIR/Ihya.dmg"
    echo "Web out klasörüne kopyalandı: $WEB_OUT_DIR/Ihya.dmg"
fi

echo "============================================="
echo "  İHYÂ v1.4.0 Universal 2 Başarıyla Üretildi!"
echo "  DMG Dosyası: $DMG_OUTPUT"
echo "  Boyut: $(du -h "$DMG_OUTPUT" | cut -f1)"
echo "============================================="
