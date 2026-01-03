import Foundation
import Combine
import AppKit
import SwiftUI

class ServiceManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = L("dashboard.inactive")
    @Published var pingResults: [String: String] = [:]
    @Published var connectionTime: Int = 0
    @Published var binaryPath: String = ""
    
    @AppStorage("autoStartEnabled") var autoStartEnabled: Bool = false
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("didAddDefaultApps") var didAddDefaultApps: Bool = false
    
    private var timer: Timer?
    private let plistName = "com.baymacdpi.ciadpi.plist"
    
    private var plistPath: String {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryPath.appendingPathComponent("LaunchAgents/\(plistName)").path
    }
    
    private var byedpiPath: String {
        // Priority: Custom > Application Support > Bundle
        if let custom = UserDefaults.standard.string(forKey: "customBinaryPath"), 
           FileManager.default.fileExists(atPath: custom) {
            return custom
        }
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportPath = appSupport.appendingPathComponent("BayMacDPI/ciadpi").path
        if FileManager.default.fileExists(atPath: appSupportPath) {
            return appSupportPath
        }
        
        // Extract from bundle if needed
        if let bundled = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
            let fm = FileManager.default
            let folder = appSupport.appendingPathComponent("BayMacDPI")
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try? fm.copyItem(atPath: bundled, toPath: appSupportPath)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appSupportPath)
            
            // Remove quarantine
            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-d", "com.apple.quarantine", appSupportPath]
            try? xattr.run()
            xattr.waitUntilExit()
            
            return appSupportPath
        }
        
        return appSupportPath
    }
    
    init() {
        self.binaryPath = byedpiPath
        checkStatus()
        checkAutoStartStatus()
        if isRunning { startTimer() }
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
        DispatchQueue.global(qos: .userInitiated).async {
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
                        if running { self.startTimer() } else { self.stopTimer() }
                    }
                    self.statusMessage = self.isRunning ? L("dashboard.active") : L("dashboard.inactive")
                    self.binaryPath = self.byedpiPath
                    withAnimation {
                        self.isProcessing = false
                    }
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
        // Ensure binary exists
        _ = byedpiPath
        
        isProcessing = true
        statusMessage = L("dashboard.starting")
        
        // Force cleanup old processes
        runCommand("/usr/bin/killall", args: ["ciadpi"])
        
        createPlist()
        runCommand("/bin/launchctl", args: ["load", plistPath])
        
        DispatchQueue.global().async {
            self.waitForStatus(target: true)
            DispatchQueue.main.async {
                if self.systemProxyEnabled {
                    let port = UserDefaults.standard.string(forKey: "byedpiPort") ?? "1080"
                    self.enableSystemProxy(port: port)
                }
            }
        }
    }
    
    func stopService() {
        isProcessing = true
        statusMessage = L("dashboard.stopping")
        
        runCommand("/bin/launchctl", args: ["unload", plistPath])
        // Force cleanup just in case
        runCommand("/usr/bin/killall", args: ["ciadpi"])
        
        disableSystemProxy()
        
        DispatchQueue.global().async {
            self.waitForStatus(target: false)
        }
    }
    
    private func waitForStatus(target: Bool, attempts: Int = 0) {
        if attempts > 10 { // Max 5 seconds (10 * 0.5s)
            DispatchQueue.main.async {
                self.checkStatus() // Final check
            }
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "ciadpi"]
        
        try? process.run()
        process.waitUntilExit()
        
        let isRunning = (process.terminationStatus == 0)
        
        if isRunning == target {
            DispatchQueue.main.async {
                self.checkStatus() // Will update UI and stop animation
            }
        } else {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self.waitForStatus(target: target, attempts: attempts + 1)
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
        connectionTime = 0
    }
    
    func launchDiscord() {
        let port = UserDefaults.standard.string(forKey: "byedpiPort") ?? "1080"
        let args = [
            "-a", "/Applications/Discord.app/Contents/MacOS/Discord",
            "--args",
            "--proxy-server=socks5://127.0.0.1:\(port)",
            "--ignore-certificate-errors"
        ]
        runCommand("/usr/bin/open", args: args)
    }
    
    func launchVesktop() {
        let port = UserDefaults.standard.string(forKey: "byedpiPort") ?? "1080"
        let args = [
            "-a", "/Applications/Vesktop.app/Contents/MacOS/Vesktop",
            "--args",
            "--proxy-server=socks5://127.0.0.1:\(port)",
            "--ignore-certificate-errors"
        ]
        runCommand("/usr/bin/open", args: args)
    }
    
    private func createPlist() {
        let port = UserDefaults.standard.string(forKey: "byedpiPort") ?? "1080"
        let splitMode = UserDefaults.standard.string(forKey: "splitMode") ?? "1+s"
        
        let logPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BayMacDPI/byedpi.log").path
        
        // Construct arguments based on mode
        var args = [byedpiPath, "-i", "127.0.0.1", "-p", port]
        
        switch splitMode {
        case "1+s":
            args += ["-r", "1+s"]
        case "2+s":
            args += ["-r", "2+s"]
        case "fake":
            args += ["-d", "1"] // Map 'fake' to disorder 1 to prevent crash
        default:
            args += ["-r", "1+s"]
        }
        
        // Create XML Array for arguments
        let argsString = args.map { "<string>\($0)</string>" }.joined(separator: "\n        ")
        
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.baymacdpi.ciadpi</string>
            <key>ProgramArguments</key>
            <array>
                \(argsString)
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(logPath)</string>
        </dict>
        </plist>
        """
        
        // Ensure LaunchAgents folder exists
        let launchAgentsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LaunchAgents")
        try? FileManager.default.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)
        
        let pathURL = URL(fileURLWithPath: plistPath)
        try? content.write(to: pathURL, atomically: true, encoding: .utf8)
    }
    
    private func runCommand(_ launchPath: String, args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = args
            try? process.run()
            process.waitUntilExit()
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
    
    func revealInFinder() {
        let url = URL(fileURLWithPath: binaryPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
