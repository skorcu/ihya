import SwiftUI
import IhyaCore

public struct XRayDrawerView: View {
    @ObservedObject private var engine = CleanerEngine.shared
    let category: CategorySummary
    let onClose: () -> Void
    
    public init(category: CategorySummary, onClose: @escaping () -> Void) {
        self.category = category
        self.onClose = onClose
    }
    
    // Live category instance from engine to reflect selection changes
    private var liveCategory: CategorySummary {
        engine.categories.first(where: { $0.category == category.category }) ?? category
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Çekmece Başlığı
            HStack(spacing: 12) {
                Image(systemName: liveCategory.category.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveCategory.category.displayName)
                        .font(.system(size: 15, weight: .bold))
                    
                    Text("\(liveCategory.items.count) öğe • Toplam: \(liveCategory.formattedSize)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            
            Divider()
            
            // Dosya ve Öğe Listesi
            if liveCategory.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green.opacity(0.8))
                    Text("Bu kategoride silinecek çöp bulunmuyor.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(liveCategory.items) { item in
                            Button(action: {
                                engine.toggleItemSelection(categoryType: liveCategory.category, itemId: item.id)
                                HapticManager.shared.triggerClick()
                            }) {
                                HStack(spacing: 12) {
                                    // Seçim Onay Kutusu
                                    Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 16))
                                        .foregroundColor(item.isSelected ? .blue : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(item.name)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            // Güvenli Rozeti
                                            Text("Güvenli")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundColor(.green)
                                                .cornerRadius(4)
                                        }
                                        
                                        Text(item.path)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(item.formattedSize)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 400)
        .background(.ultraThinMaterial)
    }
}
