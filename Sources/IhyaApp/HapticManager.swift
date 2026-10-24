import AppKit

public final class HapticManager: Sendable {
    public static let shared = HapticManager()
    
    private init() {}
    
    @MainActor
    public func triggerClick() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }
    
    @MainActor
    public func triggerSuccess() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
    }
    
    @MainActor
    public func generateSuccessFeedback() {
        triggerSuccess()
    }
    
    @MainActor
    public func triggerWarning() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
    }
}
