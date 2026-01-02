import Foundation
import Combine

class ServiceManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = "Sistem Hazır"
    @Published var pingResults: [String: String] = [:] 
    @Published var autoStartEnabled: Bool = false
    @Published var connectionTime: Int = 0
    
    private var timer: Timer?
    private let plistName = "com.user.byedpi.plist"
    
    private var plistPath: String {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryPath.appendingPathComponent("LaunchAgents/\(plistName)").path
    }
    
    // Dynamic paths for ByeDPI
    private var appSupportDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ByeDPI")
    }
    
    private var byedpiPath: String {
        return appSupportDir.appendingPathComponent("ciadpi").path
    }
    
    private var logPath: String {
        return appSupportDir.appendingPathComponent("byedpi.log").path
    }
    
    private var errorLogPath: String {
        return appSupportDir.appendingPathComponent("byedpi_error.log").path
    }
    
    init() {
        setupByeDPI()
        checkStatus()
        checkAutoStartStatus()
        if isRunning { startTimer() }
    }
    
    /// Extract bundled ciadpi binary to Application Support on first run
    private func setupByeDPI() {
        let fm = FileManager.default
        
        // Create Application Support/ByeDPI directory
        if !fm.fileExists(atPath: appSupportDir.path) {
            try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        
        // Check if binary needs to be extracted
        if !fm.fileExists(atPath: byedpiPath) {
            // Get bundled binary from Resources
            if let bundledPath = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
                do {
                    try fm.copyItem(atPath: bundledPath, toPath: byedpiPath)
                    // Make executable
                    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: byedpiPath)
                    print("ByeDPI binary extracted to: \(byedpiPath)")
                } catch {
                    print("Failed to extract ByeDPI binary: \(error)")
                }
            } else {
                print("WARNING: Bundled ciadpi not found in Resources")
            }
        }
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "ciadpi"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            DispatchQueue.main.async {
                let running = (process.terminationStatus == 0)
                if running != self.isRunning {
                    self.isRunning = running
                    if running {
                        self.startTimer()
                    } else {
                        self.stopTimer()
                        self.connectionTime = 0
                    }
                }
                self.statusMessage = self.isRunning ? "ByeDPI Aktif" : "ByeDPI Kapalı"
            }
        } catch {
            print("Status check error: \(error)")
        }
    }
    
    func toggleService() {
        if isRunning { stopService() } else { startService() }
    }
    
    func startService() {
        createPlist()
        runCommand("/bin/launchctl", args: ["load", plistPath])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { 
            self.checkStatus()
        }
    }
    
    func stopService() {
        runCommand("/bin/launchctl", args: ["unload", plistPath])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { 
            self.checkStatus()
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
    
    private func createPlist() {
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.user.byedpi</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(byedpiDetails.path)</string>
                <string>-r</string>
                <string>1+s</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/Users/abdullah/.byedpi/byedpi.log</string>
            <key>StandardErrorPath</key>
            <string>/Users/abdullah/.byedpi/byedpi_error.log</string>
        </dict>
        </plist>
        """
        let pathURL = URL(fileURLWithPath: plistPath)
        try? content.write(to: pathURL, atomically: true, encoding: .utf8)
    }
    
    private func runCommand(_ launchPath: String, args: [String]) {
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
