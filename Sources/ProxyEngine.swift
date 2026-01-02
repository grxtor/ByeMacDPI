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
    
    private var process: Process?
    
    var binaryPath: String {
        if let customPath = UserDefaults.standard.string(forKey: "customBinaryPath") {
            return customPath
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("BayMacDPI/ciadpi").path
    }
    
    var logPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("BayMacDPI/byedpi.log").path
    }
    
    var isRunning: Bool = false
    
    init() {
        Task { await ensureBinaryExists() }
    }
    
    private func ensureBinaryExists() async {
        let fm = FileManager.default
        let path = binaryPath
        
        if fm.fileExists(atPath: path) { return }
        
        // 1. Try Bundle
        if let bundled = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
            try? fm.copyItem(atPath: bundled, toPath: path)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            return
        }
        
        // 2. Download Fallback
        await downloadBinary()
    }
    
    private func downloadBinary() async {
        print("Downloading ciadpi...")
        // Detect architecture
        #if arch(arm64)
        let binaryName = "ciadpi-macos-arm64"
        #else
        let binaryName = "ciadpi-macos-x86_64"
        #endif
        
        guard let url = URL(string: "https://github.com/hufrea/byedpi/releases/latest/download/\(binaryName)") else { return }
        
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let fm = FileManager.default
            let folder = URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
            
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            
            if fm.fileExists(atPath: binaryPath) {
                try fm.removeItem(atPath: binaryPath)
            }
            
            try fm.moveItem(at: tempURL, to: URL(fileURLWithPath: binaryPath))
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryPath)
            print("Downloaded ciadpi to \(binaryPath)")
        } catch {
            print("Download failed: \(error)")
        }
    }
    
    func start(args: [String]) async throws {
        // Ensure binary exists before starting
        if !FileManager.default.fileExists(atPath: binaryPath) {
             await downloadBinary()
             if !FileManager.default.fileExists(atPath: binaryPath) {
                 throw NSError(domain: "Ciadpi", code: 404, userInfo: [NSLocalizedDescriptionKey: "Binary not found and download failed."])
             }
        }
    
        let task = Process()
        task.executableURL = URL(fileURLWithPath: binaryPath)
        task.arguments = args
        
        // Logging
        let fm = FileManager.default
        if !fm.fileExists(atPath: logPath) {
             fm.createFile(atPath: logPath, contents: nil)
        }
        let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
        fileHandle?.seekToEndOfFile()
        
        task.standardOutput = fileHandle
        task.standardError = fileHandle
        
        try task.run()
        self.process = task
        self.isRunning = true
    }
    
    func stop() async {
        process?.terminate()
        process = nil
        
        // Fallback cleanup
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "ciadpi"]
        try? task.run() 
        task.waitUntilExit()
        
        self.isRunning = false
    }
    
    func checkStatus() async -> Bool {
        if process != nil && process!.isRunning { return true }
        
        // Fallback pgrep check (in case it was started externally or process var lost)
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
