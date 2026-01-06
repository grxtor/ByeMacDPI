import Foundation

class ByeDPIEngine: ProxyEngine {
    let type: ProxyEngineType = .byedpi
    private(set) var isRunning: Bool = false
    private var process: Process?
    
    func start(port: String, preset: BypassPreset?) async throws {
        guard let binaryPath = DependencyManager.shared.getPath(.ciadpi) else {
            throw DependencyError.installFailed("ByeDPI binary bulunamadı")
        }
        
        stop()
        
        let logPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ByeMacDPI/byedpi.log").path
        
        var args = ["-i", "127.0.0.1", "-p", port]
        
        if let preset = preset {
            args += preset.args.split(separator: " ").map(String.init)
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: binaryPath)
        process?.arguments = args
        
        // Redirect logs
        let logURL = URL(fileURLWithPath: logPath)
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        process?.standardOutput = try? FileHandle(forWritingTo: logURL)
        process?.standardError = try? FileHandle(forWritingTo: logURL)
        
        try process?.run()
        isRunning = true
        
        print("[ByeDPIEngine] 🚀 Started on port \(port) with preset \(preset?.id ?? "none")")
    }
    
    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        
        // Kill any leaked processes
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killProcess.arguments = ["ciadpi"]
        try? killProcess.run()
        killProcess.waitUntilExit()
    }
}
