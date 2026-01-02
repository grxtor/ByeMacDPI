import Foundation
import Combine

protocol ProxyEngine {
    var name: String { get }
    var binaryPath: String { get }
    var isRunning: Bool { get }
    
    func start(args: [String]) async throws
    func stop() async
    func checkStatus() async -> Bool
}

class CiadpiEngine: ProxyEngine {
    var name: String = "Ciadpi"
    
    var binaryPath: String {
        if let customPath = UserDefaults.standard.string(forKey: "customBinaryPath") {
            return customPath
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("BayMacDPI/ciadpi").path
    }
    
    var isRunning: Bool = false
    
    init() {
        setupByeDPI()
    }
    
    private func setupByeDPI() {
        let fm = FileManager.default
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bayBayDir = appSupport.appendingPathComponent("BayMacDPI")
        let targetPath = bayBayDir.appendingPathComponent("ciadpi").path
        
        // Ensure directory exists
        if !fm.fileExists(atPath: bayBayDir.path) {
            try? fm.createDirectory(at: bayBayDir, withIntermediateDirectories: true)
        }
        
        // Check if exists
        if fm.fileExists(atPath: targetPath) { return }
        
        // Extract from bundle
        if let bundled = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
            try? fm.copyItem(atPath: bundled, toPath: targetPath)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetPath)
        } else {
            // Download fallback (simplified for engine)
            print("Ciadpi binary not found in bundle!")
        }
    }
    
    func start(args: [String]) async throws {
        // Construct command
        // ciadpi needs full command line or we construct it here?
        // ServiceManager constructs it currently.
        // We will move construction here or pass arguments.
        // For simplicity, we pass the raw arguments list.
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binaryPath)
        task.arguments = args
        
        // Output handling
        task.standardOutput = FileHandle.nullDevice // or pipe if we want logs
        task.standardError = FileHandle.nullDevice
        
        try task.run()
        // We don't wait for exit, it's a daemon/service
    }
    
    func stop() async {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "ciadpi"]
        try? task.run() // we don't await compilation of pkill usually
        task.waitUntilExit()
    }
    
    func checkStatus() async -> Bool {
        // Use pgrep to check if running
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "ciadpi"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
