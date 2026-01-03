import Foundation
import Combine
import AppKit
import SwiftUI

// MARK: - Bypass Preset Model
struct BypassPreset: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let localizedNameKey: String
    let icon: String
    let descriptionKey: String
    let args: [String]
    let proxyType: String
    
    var localizedName: String { L(localizedNameKey) }
    var localizedDescription: String { L(descriptionKey) }
}

// MARK: - Preset Definitions
struct PresetManager {
    static let presets: [BypassPreset] = [
        // Temel Modlar
        BypassPreset(
            id: "standard",
            name: "Standard",
            localizedNameKey: "preset.standard",
            icon: "shield",
            descriptionKey: "preset.standard.desc",
            args: ["--split", "1+s"],
            proxyType: "socks5"
        ),
        BypassPreset(
            id: "gaming",
            name: "Gaming",
            localizedNameKey: "preset.game",
            icon: "gamecontroller",
            descriptionKey: "preset.gaming.desc",
            args: ["--disorder", "1", "--split", "1+s"],
            proxyType: "socks5"
        ),
        BypassPreset(
            id: "streaming",
            name: "Streaming",
            localizedNameKey: "preset.streaming",
            icon: "play.tv",
            descriptionKey: "preset.streaming.desc",
            args: ["--split", "2+s", "--auto=torst"],
            proxyType: "http"
        ),
        BypassPreset(
            id: "privacy",
            name: "Privacy",
            localizedNameKey: "preset.privacy",
            icon: "eye.slash",
            descriptionKey: "preset.privacy.desc",
            args: ["--split", "1+s", "--tlsrec", "3+s"],
            proxyType: "https"
        ),
        
        // Discord Özel
        BypassPreset(
            id: "discord",
            name: "Discord",
            localizedNameKey: "preset.discord",
            icon: "message",
            descriptionKey: "preset.discord.desc",
            args: ["--disorder", "1", "--split", "1+s", "--auto=torst"],
            proxyType: "socks5"
        ),

        
        // Gelişmiş Bypass
        BypassPreset(
            id: "stealth",
            name: "Stealth",
            localizedNameKey: "preset.stealth",
            icon: "eye.trianglebadge.exclamationmark",
            descriptionKey: "preset.stealth.desc",
            args: ["--tlsrec", "1+s", "--auto=torst"],
            proxyType: "socks5"
        ),

        BypassPreset(
            id: "oob",
            name: "OOB",
            localizedNameKey: "preset.oob",
            icon: "arrow.up.message",
            descriptionKey: "preset.oob.desc",
            args: ["--oob", "3+s", "--split", "1"],
            proxyType: "socks5"
        ),

        
        // Hafif Modlar
        BypassPreset(
            id: "light",
            name: "Light",
            localizedNameKey: "preset.light",
            icon: "leaf",
            descriptionKey: "preset.light.desc",
            args: ["--split", "1"],
            proxyType: "socks5"
        ),
        BypassPreset(
            id: "custom",
            name: "Custom",
            localizedNameKey: "preset.custom",
            icon: "slider.horizontal.3",
            descriptionKey: "preset.custom.desc",
            args: [],
            proxyType: "socks5"
        )
    ]
    
    static func preset(for id: String) -> BypassPreset? {
        presets.first { $0.id == id }
    }
}

class ServiceManager: ObservableObject {
    static let shared = ServiceManager()
    
    private func log(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.logs += message + "\n"
            // Keep last 10000 chars
            if self.logs.count > 10000 {
                self.logs = String(self.logs.suffix(10000))
            }
        }
    }
    
    @Published var isRunning: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = L("dashboard.inactive")
    @Published var pingResults: [String: String] = [:]
    @Published var connectionTime: Int = 0
    @Published var binaryPath: String = ""
    @Published var errorMessage: String? = nil
    @Published var logs: String = ""
    private var logPipe: Pipe?
    
    @AppStorage("autoStartEnabled") var autoStartEnabled: Bool = false
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("didAddDefaultApps") var didAddDefaultApps: Bool = false
    
    private var timer: Timer?
    private var statusSyncTimer: Timer?
    private let plistName = "com.byemacdpi.ciadpi.plist"
    
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
        let appSupportPath = appSupport.appendingPathComponent("ByeMacDPI/ciadpi").path
        if FileManager.default.fileExists(atPath: appSupportPath) {
            return appSupportPath
        }
        
        // Extract from bundle if needed
        if let bundled = Bundle.main.path(forResource: "ciadpi", ofType: nil) {
            let fm = FileManager.default
            let folder = appSupport.appendingPathComponent("ByeMacDPI")
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
        checkAutoStartStatus()
        
        // Clean start: Kill any stale processes first
        DispatchQueue.global(qos: .userInitiated).async {
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            kill.arguments = ["-9", "ciadpi"]
            kill.standardOutput = FileHandle.nullDevice
            kill.standardError = FileHandle.nullDevice
            try? kill.run()
            kill.waitUntilExit()
            
            DispatchQueue.main.async {
                if self.autoStartEnabled {
                    log("[ByeMacDPI] 🚀 Auto-starting clean service...")
                    self.startService()
                } else {
                    self.checkStatus()
                }
                self.startStatusSync()
            }
        }
    }
    
    func startStatusSync() {
        // Periodic check to ensure UI matches reality
        statusSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isProcessing {
                self.checkStatus()
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
    
    func restartService() {
        log("[ByeMacDPI] 🔄 Restarting Service...")
        if isRunning {
            stopService {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startService()
                }
            }
        } else {
            startService()
        }
    }
    
    func startService() {
        // Ensure binary exists
        let binary = byedpiPath
        if !FileManager.default.fileExists(atPath: binary) {
             log("[ByeMacDPI] ❌ Binary not found at \(binary)")
             DispatchQueue.main.async {
                 self.errorMessage = "Hata: CiaDPI binary dosyası bulunamadı!\nKonum: \(binary)"
                 self.statusMessage = "Binary Hatası"
                 self.isProcessing = false
             }
             return
        }
        
        // Ensure executable
        if !FileManager.default.isExecutableFile(atPath: binary) {
             log("[ByeMacDPI] ⚠️ Binary not executable, attempting chmod +x")
             let chmod = Process()
             chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
             chmod.arguments = ["+x", binary]
             try? chmod.run()
             chmod.waitUntilExit()
        }

        // Force cleanup of existing process
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killTask.arguments = ["-9", "ciadpi"]
        try? killTask.run()
        killTask.waitUntilExit()
        
        Thread.sleep(forTimeInterval: 0.5) // Wait for port release
        
        isProcessing = true
        statusMessage = L("dashboard.starting")
        
        // Build arguments from settings
        let port = UserDefaults.standard.string(forKey: "byedpiPort") ?? "1080"
        let activePreset = UserDefaults.standard.string(forKey: "activePreset") ?? "standard"
        let customArgs = UserDefaults.standard.string(forKey: "customByedpiArgs") ?? ""
        
        let ttlValue = UserDefaults.standard.string(forKey: "ttlValue") ?? "8"
        // let timeout = UserDefaults.standard.string(forKey: "connectionTimeout") ?? "5" // Deprecated
        let maxConnValue = UserDefaults.standard.string(forKey: "maxConnections") ?? "512"
        let cacheTTL = UserDefaults.standard.string(forKey: "cacheTTL") ?? "100800"
        let autoMode = UserDefaults.standard.string(forKey: "autoMode") ?? "1"

        let noUDP = UserDefaults.standard.bool(forKey: "noUDP")
        let defTTL = UserDefaults.standard.string(forKey: "defTTL") ?? ""
        
        log("[ByeMacDPI] ══════════════════════════════════════")
        log("[ByeMacDPI] 🚀 Starting ByeDPI Service")
        log("[ByeMacDPI] ──────────────────────────────────────")
        log("[ByeMacDPI] 📋 Active Preset: \(activePreset)")
        
        var args = ["-i", "127.0.0.1", "-p", port]
        
        // Advanced Params
        args += ["-c", maxConnValue]
        args += ["-u", cacheTTL]
        args += ["-L", autoMode]
        
        if !defTTL.isEmpty {
            args += ["-g", defTTL]
        }
        

        
        if noUDP {
            args += ["-U"]
        }
        
        // Preset / Custom Args
        if activePreset == "custom" && !customArgs.isEmpty {
             let customArgsParsed = customArgs.split(separator: " ").map(String.init)
             args += customArgsParsed
             log("[ByeMacDPI] 🔧 Custom Args: \(customArgs)")
        } else if let preset = PresetManager.preset(for: activePreset) {
            args += preset.args
            
            // Override TTL if fake mode is used
            if preset.args.contains("--fake") || preset.args.contains("-f") {
                // Find existing TTL
                if let idx = args.firstIndex(of: "--ttl"), idx + 1 < args.count {
                    args[idx + 1] = ttlValue
                } else if let idx = args.firstIndex(of: "-t"), idx + 1 < args.count {
                    args[idx + 1] = ttlValue
                }
            }
            log("[ByeMacDPI] 🎯 Preset Args: \(preset.args.joined(separator: " "))")
        } else {
            args += ["--split", "1+s"]
            log("[ByeMacDPI] ⚠️  Preset not found, using default")
        }
        
        log("[ByeMacDPI] ──────────────────────────────────────")
        log("[ByeMacDPI] 📝 Full Command: ciadpi \(args.joined(separator: " "))")
        log("[ByeMacDPI] ══════════════════════════════════════")
        
        // Start ciadpi directly
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: binary)
            task.arguments = args
            
            // Capture output
            let pipe = Pipe()
            self.logPipe = pipe
            task.standardOutput = pipe
            task.standardError = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    self?.log(str.trimmingCharacters(in: .newlines))
                }
            }
            
            do {
                try task.run()
                log("[ByeMacDPI] ✅ Started ciadpi with PID: \(task.processIdentifier)")
                
                DispatchQueue.main.async {
                    self.waitForStatus(target: true)
                    if self.systemProxyEnabled {
                        log("[ByeMacDPI] 🌐 Enabling System Proxy on port \(port)...")
                        self.enableSystemProxy(port: port)
                    }
                }
            } catch {
                log("[ByeMacDPI] ❌ Failed to start: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Servis başlatılamadı:\n\(error.localizedDescription)"
                    self.statusMessage = L("common.error")
                    self.isProcessing = false
                }
            }
        }
    }
    
    func stopService(completion: (() -> Void)? = nil) {
        isProcessing = true
        statusMessage = L("dashboard.stopping")
        
        log("[ByeMacDPI] 🛑 Stopping ByeDPI Service...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Unload from launchd (in case it was loaded previously)
            // Even though we use direct process now, checking ensure no zombie service remains
            let launchctlTask = Process()
            launchctlTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            launchctlTask.arguments = ["unload", self.plistPath]
            launchctlTask.standardOutput = FileHandle.nullDevice
            launchctlTask.standardError = FileHandle.nullDevice
            try? launchctlTask.run()
            launchctlTask.waitUntilExit()
            
            // 2. Kill ciadpi directly (SIGKILL -9)
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["-9", "ciadpi"]
            killTask.standardOutput = FileHandle.nullDevice
            killTask.standardError = FileHandle.nullDevice
            try? killTask.run()
            killTask.waitUntilExit()
            
            // 3. Fallback with pkill (SIGKILL -9)
            let pkillTask = Process()
            pkillTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            pkillTask.arguments = ["-9", "-f", "ciadpi"]
            pkillTask.standardOutput = FileHandle.nullDevice
            pkillTask.standardError = FileHandle.nullDevice
            try? pkillTask.run()
            pkillTask.waitUntilExit()
            
            log("[ByeMacDPI] ✅ ByeDPI Service stopped")
            
            DispatchQueue.main.async {
                log("[ByeMacDPI] 🌐 Disabling System Proxy...")
                self.disableSystemProxy()
                self.waitForStatus(target: false)
                completion?()
            }
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
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
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
        let activePreset = UserDefaults.standard.string(forKey: "activePreset") ?? "standard"
        let customArgs = UserDefaults.standard.string(forKey: "customByedpiArgs") ?? ""
        
        // Advanced parameters
        let ttlValue = UserDefaults.standard.string(forKey: "ttlValue") ?? "8"
        let timeoutValue = UserDefaults.standard.string(forKey: "connectionTimeout") ?? "5"
        let maxConnValue = UserDefaults.standard.string(forKey: "maxConnections") ?? "512"
        let cacheTTL = UserDefaults.standard.string(forKey: "cacheTTL") ?? "100800"
        let autoMode = UserDefaults.standard.string(forKey: "autoMode") ?? "1"

        let noUDP = UserDefaults.standard.bool(forKey: "noUDP")
        let defTTL = UserDefaults.standard.string(forKey: "defTTL") ?? ""
        
        let logPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ByeMacDPI/byedpi.log").path
        
        // Start with base arguments
        var args = [byedpiPath, "-i", "127.0.0.1", "-p", port]
        
        // Add advanced parameters
        args += ["-c", maxConnValue]
        args += ["-u", cacheTTL]
        args += ["-L", autoMode]
        
        if !defTTL.isEmpty {
            args += ["-g", defTTL]
        }
        

        
        if noUDP {
            args += ["-U"]
        }
        
        // Apply preset arguments
        if activePreset == "custom" && !customArgs.isEmpty {
            // Custom mode - use user-defined args
            let customArgsParsed = customArgs.split(separator: " ").map(String.init)
            args += customArgsParsed
        } else if let preset = PresetManager.preset(for: activePreset) {
            // Use preset args
            args += preset.args
            
            // Override TTL if fake mode is used
            if preset.args.contains("--fake") || preset.args.contains("-f") {
                if let ttlIndex = args.firstIndex(of: "--ttl") {
                    // Already has TTL, use custom value if different
                    if ttlIndex + 1 < args.count {
                        args[ttlIndex + 1] = ttlValue
                    }
                } else if let ttlIndex = args.firstIndex(of: "-t") {
                    if ttlIndex + 1 < args.count {
                        args[ttlIndex + 1] = ttlValue
                    }
                }
            }
            
            // Override timeout
            if preset.args.contains("--auto") || preset.args.contains("-A") {
                // Auto mode might need adjustments but standard args should be fine
            }
        } else {
            // Fallback to standard
            args += ["--split", "1+s"]
        }
        
        // Create XML Array for arguments
        let argsString = args.map { "<string>\($0)</string>" }.joined(separator: "\n        ")
        
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.byemacdpi.ciadpi</string>
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
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
    
    func enableSystemProxy(port: String) {
        DispatchQueue.main.async { self.statusMessage = "Enabling System Proxy..." }
        let service = "Wi-Fi"
        runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxy", service, "127.0.0.1", port])
        runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxystate", service, "on"])
    }
    
    func disableSystemProxy() {
        DispatchQueue.main.async { self.statusMessage = "Disabling System Proxy..." }
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
