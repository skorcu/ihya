import Foundation

public final class GhostDaemonEngine: Sendable {
    public static let shared = GhostDaemonEngine()
    
    public init() {}
    
    public func scanGhostDaemons() async -> [GhostDaemonItem] {
        var ghosts: [GhostDaemonItem] = []
        let home = NSHomeDirectory()
        
        let targetDirs = [
            ((home as NSString).appendingPathComponent("Library/LaunchAgents"), true),
            ("/Library/LaunchAgents", false),
            ("/Library/LaunchDaemons", false)
        ]
        
        for (dirPath, isUser) in targetDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in contents where file.hasSuffix(".plist") {
                let plistPath = (dirPath as NSString).appendingPathComponent(file)
                guard let dict = NSDictionary(contentsOfFile: plistPath) else { continue }
                
                var binaryPath: String? = dict["Program"] as? String
                if binaryPath == nil, let args = dict["ProgramArguments"] as? [String], !args.isEmpty {
                    binaryPath = args[0]
                }
                
                if let bin = binaryPath {
                    // Sistem Apple dahili binary'lerini es geç
                    if bin.hasPrefix("/System") || bin.hasPrefix("/usr/libexec") || bin.hasPrefix("/usr/bin") || bin.hasPrefix("/bin") {
                        continue
                    }
                    
                    // Eğer hedef program dosyası diskte yoksa -> Hayalet servis!
                    if !FileManager.default.fileExists(atPath: bin) {
                        let label = (dict["Label"] as? String) ?? file
                        ghosts.append(GhostDaemonItem(
                            label: label,
                            plistPath: plistPath,
                            missingBinaryPath: bin,
                            isUserAgent: isUser
                        ))
                    }
                }
            }
        }
        
        return ghosts
    }
}
