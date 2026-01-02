import Foundation
import Combine
import AppKit

class ServiceManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = "Sistem Hazır"
    @Published var pingResults: [String: String] = [:] 
    @Published var autoStartEnabled: Bool = false
    @Published var connectionTime: Int = 0
    
    private var timer: Timer?
    private let plistName = "com.baymacdpi.service.plist"
    
    private var plistPath: String {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let agentsDir = libraryPath.appendingPathComponent("LaunchAgents")
        if !FileManager.default.fileExists(atPath: agentsDir.path) {
            try? FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        }
        return agentsDir.appendingPathComponent(plistName).path
    }
    
    // Dynamic paths for ByeDPI
    private var appSupportDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("BayMacDPI")
    }
    
    private var byedpiPath: String {
        // Return custom path if set and valid, otherwise fallback to default
        if let customPath = UserDefaults.standard.string(forKey: "customBinaryPath"), !customPath.isEmpty {
            return customPath
        }
        return appSupportDir.appendingPathComponent("ciadpi").path
    }
    
    private var logPath: String {
        return appSupportDir.appendingPathComponent("byedpi.log").path
    }
    
    private var errorLogPath: String {
        return appSupportDir.appendingPathComponent("byedpi_error.log").path
    }
    
    var binaryPath: String { byedpiPath }
    
    init() {
        setupByeDPI()
        checkStatus()
        checkAutoStartStatus()
        if isRunning { startTimer() }
    }
    
    /// Extract bundled ciadpi binary to Application Support on first run, or download if not available
    private func setupByeDPI() {
        let fm = FileManager.default
        
        // Create Application Support/ByeDPI directory
        if !fm.fileExists(atPath: appSupportDir.path) {
            try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        
        // Check if binary already exists
        if fm.fileExists(atPath: byedpiPath) {
            return
        }
        
        // Try to get bundled binary from Resources first
        if let bundledPath = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
            do {
                try fm.copyItem(atPath: bundledPath, toPath: byedpiPath)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: byedpiPath)
                print("ByeDPI binary extracted from bundle to: \(byedpiPath)")
                return
            } catch {
                print("Failed to extract bundled binary: \(error)")
            }
        }
        
        // If bundle extraction failed, download from GitHub
        print("Downloading ByeDPI binary from GitHub...")
        DispatchQueue.main.async {
            self.statusMessage = "BayMacDPI indiriliyor..."
        }
        downloadByeDPI()
    }
    
    /// Download ciadpi binary from GitHub releases
    private func downloadByeDPI() {
        // Detect architecture
        #if arch(arm64)
        let binaryName = "ciadpi-macos-arm64"
        #else
        let binaryName = "ciadpi-macos-x86_64"
        #endif
        
        let downloadURL = "https://github.com/hufrea/byedpi/releases/latest/download/\(binaryName)"
        
        guard let url = URL(string: downloadURL) else {
            print("Invalid download URL")
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { [self] tempURL, response, error in
            guard let tempURL = tempURL, error == nil else {
                print("Download failed: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.statusMessage = "İndirme başarısız!"
                }
                return
            }
            
            do {
                let fm = FileManager.default
                // Remove existing file if any
                if fm.fileExists(atPath: byedpiPath) {
                    try fm.removeItem(atPath: byedpiPath)
                }
                // Move downloaded file
                try fm.moveItem(at: tempURL, to: URL(fileURLWithPath: byedpiPath))
                // Make executable
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: byedpiPath)
                
                print("ByeDPI binary downloaded and installed to: \(byedpiPath)")
                DispatchQueue.main.async {
                    self.statusMessage = "BayMacDPI kuruldu!"
                }
            } catch {
                print("Failed to install downloaded binary: \(error)")
                DispatchQueue.main.async {
                    self.statusMessage = "Kurulum başarısız!"
                }
            }
        }
        task.resume()
    }
    
    func checkAutoStartStatus() {
        autoStartEnabled = FileManager.default.fileExists(atPath: plistPath)
    }
    
    func toggleAutoStart() {
        if autoStartEnabled { disableAutoStart() } else { enableAutoStart() }
    }
    
    func enableAutoStart() {
        createPlist()
        autoStartEnabled = true
    }
    
    func disableAutoStart() {
        try? FileManager.default.removeItem(atPath: plistPath)
        autoStartEnabled = false
    }
    
    func checkStatus() {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            process.arguments = ["-x", "ciadpi"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let isRunningNow = (process.terminationStatus == 0)
                
                DispatchQueue.main.async {
                    if isRunningNow != self.isRunning {
                        self.isRunning = isRunningNow
                        if isRunningNow {
                            self.startTimer()
                        } else {
                            self.stopTimer()
                            self.connectionTime = 0
                        }
                    }
                    self.statusMessage = self.isRunning ? "BayMacDPI Aktif" : "BayMacDPI Kapalı"
                }
            } catch {
                print("Status check error: \(error)")
            }
        }
    }
    
    func toggleService() {
        if isRunning { stopService() } else { startService() }
    }
    
    func startService() {
        createPlist()
        // Run in background to avoid UI lag
        Task {
            runCommand("/bin/launchctl", args: ["bootstrap", "gui/\(getuid())", plistPath])
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { 
                self.checkStatus()
            }
        }
    }
    
    func stopService() {
        // Run in background to avoid UI lag
        Task {
            runCommand("/bin/launchctl", args: ["bootout", "gui/\(getuid())", plistPath])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { 
                self.checkStatus()
            }
        }
    }
    
    func startTimer() {
        stopTimer()
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                self.connectionTime += 1
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func launchDiscord() {
        // Launch Discord with proxy args
        let args = [
            "-a", "/Applications/Discord.app",
            "--args",
            "--proxy-server=socks5://127.0.0.1:1080",
            "--ignore-certificate-errors"
        ]
        runCommand("/usr/bin/open", args: args)
    }
    
    func revealInFinder() {
        let url = URL(fileURLWithPath: byedpiPath).deletingLastPathComponent()
        NSWorkspace.shared.selectFile(byedpiPath, inFileViewerRootedAtPath: url.path)
    }
    
    private func createPlist() {
        // Read user settings from UserDefaults
        let defaults = UserDefaults.standard
        let splitMode = defaults.string(forKey: "splitMode") ?? "1+s"
        let port = defaults.string(forKey: "byedpiPort") ?? "1080"
        
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.baymacdpi.service</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(byedpiPath)</string>
                <string>-p</string>
                <string>\(port)</string>
                <string>-r</string>
                <string>\(splitMode)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(errorLogPath)</string>
        </dict>
        </plist>
        """
        let pathURL = URL(fileURLWithPath: plistPath)
        try? content.write(to: pathURL, atomically: true, encoding: .utf8)
    }
    
    private func runCommand(_ launchPath: String, args: [String]) {
        // Run on background queue to keep UI responsive
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = args
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Command failed: \(error)")
            }
        }
    }
    
    func enableSystemProxy(port: String) {
        let service = "Wi-Fi"
        runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxy", service, "127.0.0.1", port])
        runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxystate", service, "on"])
    }
    
    func disableSystemProxy() {
        runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxystate", "Wi-Fi", "off"])
    }
    
    func pingDNS(host: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "1000", host]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8),
                   let range = output.range(of: "time=") {
                    let time = output[range.upperBound...].prefix(while: { $0 != " " })
                    DispatchQueue.main.async { self.pingResults[host] = "\(time) ms" }
                } else {
                    DispatchQueue.main.async { self.pingResults[host] = "Err" }
                }
            } catch {
                DispatchQueue.main.async { self.pingResults[host] = "Fail" }
            }
        }
    }
}
