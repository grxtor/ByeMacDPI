import Foundation
import Combine
import AppKit
import SwiftUI

class ServiceManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = L("dashboard.inactive")
    @Published var connectionTime: Int = 0
    @Published var binaryPath: String = ""
    @Published var pingResults: [String: String] = [:]
    
    // Engine - Default to Ciadpi
    private var engine: ProxyEngine = CiadpiEngine()
    
    // Timer
    private var timer: AnyCancellable?
    
    // User Settings
    @AppStorage("autoStartEnabled") var autoStartEnabled: Bool = false // Launches App at Login (Logical placeholder)
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("didAddDefaultApps") var didAddDefaultApps: Bool = false
    
    init() {
        self.binaryPath = engine.binaryPath
        
        // Initial Check
        checkStatus()
        
        // Auto Connect Logic (if app was restarted)
        // Note: Real "Start at Login" requires SMAppService or helper app. 
        // For now, we assume if the app is open, we might want to autostart the proxy.
        if UserDefaults.standard.bool(forKey: "autoConnect") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !self.isRunning {
                    self.startService()
                }
            }
        }
    }
    
    func toggleService() {
        if isRunning {
            stopService()
        } else {
            startService()
        }
    }
    
    func startService() {
        self.statusMessage = L("onboarding.checking")
        
        Task {
            // 1. Prepare Arguments
            let defaults = UserDefaults.standard
            let port = defaults.string(forKey: "byedpiPort") ?? "1080"
            let splitMode = defaults.string(forKey: "splitMode") ?? "1+s"
            
            var args = [
                "-i", "127.0.0.1",
                "-p", port
            ]
            
            // Mode Logic
            if splitMode == "1+s" { args.append(contentsOf: ["-s", "1"]) }
            else if splitMode == "fake" { args.append(contentsOf: ["-f", "1"]) }
            else if splitMode == "2+s" { args.append(contentsOf: ["-s", "1", "--disorder", "2"]) } // Example mapping
            else { args.append(contentsOf: ["-s", "1"]) }
            
            // Custom Args
            if let custom = defaults.string(forKey: "byedpiArgs"), !custom.isEmpty {
                 let customSplit = custom.split(separator: " ").map(String.init)
                 args.append(contentsOf: customSplit)
            }
            
            // 2. Start Engine
            do {
                try await engine.start(args: args)
                
                // 3. Update UI & System
                await MainActor.run {
                    self.isRunning = true
                    self.statusMessage = L("dashboard.active")
                    self.startTimer()
                    
                    if self.systemProxyEnabled {
                        self.enableSystemProxy(port: port)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isRunning = false
                    self.statusMessage = "\(L("common.error")): \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopService() {
        Task {
            await engine.stop()
            
            await MainActor.run {
                self.isRunning = false
                self.statusMessage = L("dashboard.inactive")
                self.stopTimer()
                self.disableSystemProxy()
            }
        }
    }
    
    func checkStatus() {
        Task {
            let running = await engine.checkStatus()
            await MainActor.run {
                // Only update if changed to avoid UI flickering
                if self.isRunning != running {
                    self.isRunning = running
                    self.statusMessage = running ? L("dashboard.active") : L("dashboard.inactive")
                }
                
                self.binaryPath = engine.binaryPath
                
                if running && self.timer == nil {
                    self.startTimer()
                } else if !running {
                    self.stopTimer()
                }
            }
        }
    }
    
    // MARK: - Timer
    private func startTimer() {
        stopTimer() // ensure no duplicates
        self.connectionTime = 0
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { _ in
            self.connectionTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
        connectionTime = 0
    }
    
    // MARK: - System Proxy
    func enableSystemProxy(port: String) {
        let service = "Wi-Fi"
        runBackgroundCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxy", service, "127.0.0.1", port])
        runBackgroundCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxystate", service, "on"])
    }
    
    func disableSystemProxy() {
        let service = "Wi-Fi"
        runBackgroundCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxystate", service, "off"])
    }
    
    private func runBackgroundCommand(_ launchPath: String, args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = args
            try? process.run()
            process.waitUntilExit()
        }
    }
    
    // MARK: - App Management
    func launchDiscord() {
         let ws = NSWorkspace.shared
         if let url = ws.urlForApplication(withBundleIdentifier: "com.hnc.Discord") {
             let config = NSWorkspace.OpenConfiguration()
             ws.openApplication(at: url, configuration: config)
         } else {
             // Try standard path
             let task = Process()
             task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
             task.arguments = ["-a", "/Applications/Discord.app"]
             try? task.run()
         }
    }
    
    func revealInFinder() {
        let url = URL(fileURLWithPath: binaryPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    func toggleAutoStart() {
        autoStartEnabled.toggle()
        // Implementation for Login Item would go here.
        // For now boolean is stored for UI state.
    }
    
    // MARK: - DNS Tools
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
