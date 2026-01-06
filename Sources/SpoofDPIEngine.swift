import Foundation

class SpoofDPIEngine: ProxyEngine {
    let type: ProxyEngineType = .spoofdpi
    private(set) var isRunning: Bool = false
    private var process: Process?
    
    func start(port: String, preset: BypassPreset?) async throws {
        guard let binaryPath = DependencyManager.shared.getPath(.spoofdpi) else {
            throw DependencyError.installFailed("SpoofDPI binary bulunamadı")
        }
        
        stop()
        
        let logPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ByeMacDPI/spoofdpi.log").path
        
        // SpoofDPI args: -port [port] -addr [addr]
        var args = ["-port", port, "-addr", "127.0.0.1"]
        
        // SpoofDPI has its own logic, presets might not map 1:1 but we can add some defaults
        // For now, just basic start.
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: binaryPath)
        process?.arguments = args
        
        let logURL = URL(fileURLWithPath: logPath)
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        process?.standardOutput = try? FileHandle(forWritingTo: logURL)
        process?.standardError = try? FileHandle(forWritingTo: logURL)
        
        try process?.run()
        isRunning = true
        
        print("[SpoofDPIEngine] 🚀 Started on port \(port)")
    }
    
    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killProcess.arguments = ["spoof-dpi"]
        try? killProcess.run()
        killProcess.waitUntilExit()
    }
}
