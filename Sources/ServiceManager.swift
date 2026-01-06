import Foundation
import Combine
import AppKit
import SwiftUI

// 1. Preset Türlerini Tanımlayan Enum
enum BypassStrategy: String, CaseIterable, Identifiable, Codable {
    case standard
    case gaming
    case streaming
    case privacy
    case discord
    case stealth
    case oob
    case light
    case custom

    var id: String { rawValue }

    // SF Symbol İkonları
    var iconName: String {
        switch self {
        case .standard:  return "shield.checkerboard"
        case .gaming:    return "gamecontroller.fill"
        case .streaming: return "play.tv.fill"
        case .privacy:   return "hand.raised.fill"
        case .discord:   return "bubble.left.and.bubble.right.fill"
        case .stealth:   return "eye.slash.fill"
        case .oob:       return "network.badge.shield.half.filled"
        case .light:     return "leaf.fill"
        case .custom:    return "slider.horizontal.3"
        }
    }

    // CLI Argümanları
    var arguments: String {
        switch self {
        case .standard:  return "--split 1+s"
        case .gaming:    return "--disorder 1 --split 1+s"
        case .streaming: return "--split 2+s --auto=torst"
        case .privacy:   return "--split 1+s --tlsrec 3+s"
        case .discord:   return "--disorder 1 --split 1+s --auto=torst"
        case .stealth:   return "--tlsrec 1+s --auto=torst"
        case .oob:       return "--oob 3+s --split 1"
        case .light:     return "--split 1"
        case .custom:    return ""
        }
    }

    // Localization Anahtarları
    var titleKey: String { 
        switch self {
        case .gaming: return "preset.game" // Keep original key for gaming
        default: return "preset.\(rawValue)"
        }
    }
    var descriptionKey: String { "preset.\(rawValue).desc" }
}

// 2. Kullanılacak Model
struct BypassPreset: Identifiable, Codable, Hashable {
    let id: String
    let strategy: BypassStrategy
    let nameKey: String
    let descKey: String
    let icon: String
    let args: String
    
    var localizedName: String { L(nameKey) }
    var localizedDescription: String { L(descKey) }

    init(strategy: BypassStrategy) {
        self.id = strategy.id
        self.strategy = strategy
        self.nameKey = strategy.titleKey
        self.descKey = strategy.descriptionKey
        self.icon = strategy.iconName
        self.args = strategy.arguments
    }
}

// 3. Manager
struct PresetManager {
    static let presets: [BypassPreset] = BypassStrategy.allCases.map { BypassPreset(strategy: $0) }
    
    static func preset(for id: String) -> BypassPreset? {
        presets.first { $0.id == id }
    }
}

class ServiceManager: ObservableObject {
    static let shared = ServiceManager()
    
    @Published var isRunning: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = L("dashboard.inactive")
    @Published var pingResults: [String: String] = [:]
    @Published var connectionTime: Int = 0
    @Published var binaryPath: String = ""
    @Published var errorMessage: String? = nil
    @Published var logs: String = ""
    
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("selectedEngine") var selectedEngine: ProxyEngineType = .byedpi
    @AppStorage("byedpiPort") var byedpiPort: String = "1080"
    
    private var engines: [ProxyEngineType: ProxyEngine] = [
        .byedpi: ByeDPIEngine(),
        .spoofdpi: SpoofDPIEngine()
    ]
    
    private var currentEngine: ProxyEngine {
        engines[selectedEngine] ?? engines[.byedpi]!
    }
    
    private var timer: Timer?
    private var statusSyncTimer: Timer?
    
    init() {
        self.binaryPath = DependencyManager.shared.getPath(selectedEngine.dependency) ?? ""
        startStatusSync()
    }
    
    private func log(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.logs += message + "\n"
            if self.logs.count > 10000 {
                self.logs = String(self.logs.suffix(10000))
            }
        }
    }
    
    func startStatusSync() {
        statusSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isProcessing {
                self.checkStatus()
            }
        }
    }
    
    func checkStatus() {
        let binaryName = selectedEngine.dependency.binaryName
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            process.arguments = ["-x", binaryName]
            
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
                    self.binaryPath = DependencyManager.shared.getPath(self.selectedEngine.dependency) ?? ""
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
        guard !isProcessing else { return }
        errorMessage = nil
        
        let activePresetName = UserDefaults.standard.string(forKey: "activePreset") ?? "standard"
        let preset = PresetManager.preset(for: activePresetName)
        
        withAnimation { isProcessing = true }
        log("[ByeMacDPI] 🚀 Starting \(selectedEngine.displayName)...")
        
        Task {
            do {
                try await currentEngine.start(port: byedpiPort, preset: preset)
                if systemProxyEnabled { enableSystemProxy(port: byedpiPort) }
                await MainActor.run { self.waitForStatus(target: true) }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                    self.log("[ByeMacDPI] ❌ Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func restartService() {
        stopService {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startService()
            }
        }
    }
    
    func stopService(completion: (() -> Void)? = nil) {
        guard !isProcessing else { return }
        withAnimation { isProcessing = true }
        log("[ByeMacDPI] 🛑 Stopping \(selectedEngine.displayName)...")
        
        Task {
            await currentEngine.stop()
            disableSystemProxy()
            await MainActor.run {
                self.waitForStatus(target: false)
                completion?()
            }
        }
    }
    
    func stopAllServices() {
        log("[ByeMacDPI] 🛑 Stopping All Services...")
        Task {
            for engine in engines.values { await engine.stop() }
            await DNSProxyManager.shared.stopDNSProxy()
            disableSystemProxy()
            await MainActor.run {
                self.checkStatus()
                withAnimation { self.isProcessing = false }
            }
        }
    }
    
    private func waitForStatus(target: Bool, attempts: Int = 0) {
        if attempts > 10 {
            isProcessing = false
            return
        }
        
        let binaryName = selectedEngine.dependency.binaryName
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", binaryName]
        try? process.run()
        process.waitUntilExit()
        
        if (process.terminationStatus == 0) == target {
            DispatchQueue.main.async { self.checkStatus(); self.isProcessing = false }
        } else {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self.waitForStatus(target: target, attempts: attempts + 1)
            }
        }
    }
    
    func enableSystemProxy(port: String) {
        let services = ["Wi-Fi", "Ethernet"]
        let useHTTP = (selectedEngine == .spoofdpi)
        for service in services {
            if useHTTP {
                runCommand("/usr/sbin/networksetup", args: ["-setwebproxy", service, "127.0.0.1", port])
                runCommand("/usr/sbin/networksetup", args: ["-setsecurewebproxy", service, "127.0.0.1", port])
            } else {
                runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxy", service, "127.0.0.1", port])
            }
        }
    }
    
    func disableSystemProxy() {
        let services = ["Wi-Fi", "Ethernet"]
        for service in services {
            runCommand("/usr/sbin/networksetup", args: ["-setsocksfirewallproxystate", service, "off"])
            runCommand("/usr/sbin/networksetup", args: ["-setwebproxystate", service, "off"])
            runCommand("/usr/sbin/networksetup", args: ["-setsecurewebproxystate", service, "off"])
        }
    }
    
    private func runCommand(_ launchPath: String, args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }
    
    func startTimer() { connectionTime = 0; timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in self.connectionTime += 1 } }
    func stopTimer() { timer?.invalidate(); timer = nil }
    
    func launchDiscord() {
        let args = ["-a", "/Applications/Discord.app", "--args", "--proxy-server=\(selectedEngine == .byedpi ? "socks5" : "http")://127.0.0.1:\(byedpiPort)", "--ignore-certificate-errors"]
        runCommand("/usr/bin/open", args: args)
    }
    
    func launchVesktop() {
        let args = ["-a", "/Applications/Vesktop.app", "--args", "--proxy-server=\(selectedEngine == .byedpi ? "socks5" : "http")://127.0.0.1:\(byedpiPort)", "--ignore-certificate-errors"]
        runCommand("/usr/bin/open", args: args)
    }
    
    func launchCustomApp(path: String, customArgs: String = "") {
        var args = ["-a", path, "--args", "--proxy-server=\(selectedEngine == .byedpi ? "socks5" : "http")://127.0.0.1:\(byedpiPort)"]
        if !customArgs.isEmpty {
            args += customArgs.split(separator: " ").map(String.init)
        }
        runCommand("/usr/bin/open", args: args)
    }
}
