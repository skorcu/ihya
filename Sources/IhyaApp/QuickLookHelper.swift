import AppKit

@MainActor
public final class QuickLookHelper {
    public static let shared = QuickLookHelper()
    
    private init() {}
    
    public func preview(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-p", path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
}
