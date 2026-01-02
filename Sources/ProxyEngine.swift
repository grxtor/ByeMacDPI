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
        // No async task in init anymore. 
        // We validate on start or manually.
    }
    
    private func validateAndPrepare() async throws {
        let fm = FileManager.default
        let path = binaryPath
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        
        // Ensure folder exists
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        // 1. Validation & Cleanup of existing file
        if fm.fileExists(atPath: path) {
            let attr = try? fm.attributesOfItem(atPath: path)
            let size = attr?[.size] as? Int64 ?? 0
            
            // Re-validate size (must be > 50KB for ciadpi)
            if size < 50_000 {
                print("Binary invalid (\(size) bytes). Deleting...")
                try? fm.removeItem(atPath: path)
            }
        }
        
        // 2. Copy from Bundle if missing
        if !fm.fileExists(atPath: path) {
            if let bundled = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
                print("Copying bundled binary from: \(bundled)")
                try? fm.copyItem(atPath: bundled, toPath: path)
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            }
        }
        
        // 3. Final Check - No download fallback, binary MUST be bundled
        if !fm.fileExists(atPath: path) {
             throw NSError(domain: "Ciadpi", code: 404, userInfo: [NSLocalizedDescriptionKey: "Binary not found in app bundle."])
        }
        
        // 4. Permissions & Quarantine
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        
        let chmod = Process()
        chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
        chmod.arguments = ["+x", path]
        try? chmod.run()
        chmod.waitUntilExit()
        
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-d", "com.apple.quarantine", path]
        try? xattr.run()
        xattr.waitUntilExit()
    }
    
    private func downloadBinary() async {
        print("Downloading ciadpi...")
        // Detect architecture (We know it's arm64 now for app, but let's keep it safe)
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
            
            // Validation: Check size (Binary should be > 1MB usually, definitely > 10KB)
            let attributes = try fm.attributesOfItem(atPath: binaryPath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize < 100_000 { // Less than 100KB
                try fm.removeItem(atPath: binaryPath)
                print("Download invalid (too small): \(fileSize) bytes")
                return
            }
            
            // Set permissions here too just in case
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryPath)
            
            print("Downloaded ciadpi to \(binaryPath)")
        } catch {
            print("Download failed: \(error)")
        }
    }
    
    func start(args: [String]) async throws {
        // Strict sequential validation
        try await validateAndPrepare()
    
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
