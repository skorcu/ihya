import AppKit

public final class SoundManager: Sendable {
    public static let shared = SoundManager()
    
    private init() {}
    
    @MainActor
    public func playSuccess() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        }
    }
    
    @MainActor
    public func playSuccessChime() {
        playSuccess()
    }
    
    @MainActor
    public func playCardComplete() {
        if let sound = NSSound(named: "Tink") {
            sound.play()
        }
    }
    
    @MainActor
    public func playCleanFinished() {
        if let sound = NSSound(named: "Hero") {
            sound.play()
        }
    }
}
