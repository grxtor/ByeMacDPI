import Foundation
import Combine

// MARK: - DNS Provider
enum DNSProvider: String, CaseIterable, Identifiable {
    case cloudflare = "cloudflare"
    case google = "google"
    case quad9 = "quad9"
    case mullvad = "mullvad"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cloudflare: return "Cloudflare"
        case .google: return "Google"
        case .quad9: return "Quad9"
        case .mullvad: return "Mullvad"
        }
    }
    
    var dohURL: String {
        switch self {
        case .cloudflare: return "https://1.1.1.1/dns-query"
        case .google: return "https://dns.google/dns-query"
        case .quad9: return "https://dns.quad9.net/dns-query"
        case .mullvad: return "https://dns.mullvad.net/dns-query"
        }
    }
    
    var icon: String {
        switch self {
        case .cloudflare: return "bolt.shield"
        case .google: return "g.circle"
        case .quad9: return "9.circle"
        case .mullvad: return "lock.shield"
        }
    }
    
    var description: String {
        switch self {
        case .cloudflare: return "Hızlı ve gizlilik odaklı"
        case .google: return "Güvenilir ve yaygın"
        case .quad9: return "Zararlı site koruması"
        case .mullvad: return "Log tutmaz, gizlilik odaklı"
        }
    }
}

// MARK: - DNS Proxy Manager
class DNSProxyManager: ObservableObject {
    static let shared = DNSProxyManager()
    
    @Published var isRunning: Bool = false
    @Published var isProcessing: Bool = false
    @Published var statusMessage: String = "DNS Proxy Kapalı"
    @Published var activeProvider: DNSProvider = .cloudflare
    @Published var localPort: Int = 5053
    @Published var logs: String = ""
    
    private var dnsProcess: Process?
    private var logPipe: Pipe?
    private let dependencyManager = DependencyManager.shared
    
    private func log(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.logs += message + "\n"
            if self.logs.count > 10000 {
                self.logs = String(self.logs.suffix(10000))
            }
        }
    }
    
    init() {
        checkStatus()
    }
    
    // MARK: - Public Methods
    
    func startDNSProxy(provider: DNSProvider = .cloudflare) async throws {
        guard dependencyManager.isInstalled(.cloudflared) else {
            throw DNSProxyError.dependencyMissing("cloudflared kurulu değil")
        }
        
        guard let binaryPath = dependencyManager.getPath(.cloudflared) else {
            throw DNSProxyError.binaryNotFound("cloudflared binary bulunamadı")
        }
        
        await MainActor.run {
            isProcessing = true
            statusMessage = "DNS Proxy Başlatılıyor..."
            activeProvider = provider
        }
        
        // Kill any existing process
        await stopDNSProxy()
        
        // Wait for port release
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "proxy-dns",
            "--port", String(localPort),
            "--upstream", provider.dohURL
        ]
        
        let pipe = Pipe()
        self.logPipe = pipe
        process.standardOutput = pipe
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                self?.log("[cloudflared] \(str.trimmingCharacters(in: .newlines))")
            }
        }
        
        do {
            try process.run()
            self.dnsProcess = process
            
            log("[DNSProxy] ✅ Started cloudflared DNS proxy on port \(localPort)")
            log("[DNSProxy] 📡 Upstream: \(provider.dohURL)")
            
            await MainActor.run {
                isRunning = true
                isProcessing = false
                statusMessage = "DNS Proxy Çalışıyor (\(provider.displayName))"
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                statusMessage = "Başlatma Hatası"
            }
            throw DNSProxyError.startFailed(error.localizedDescription)
        }
    }
    
    func stopDNSProxy() async {
        await MainActor.run {
            isProcessing = true
            statusMessage = "DNS Proxy Durduruluyor..."
        }
        
        // Terminate current process
        dnsProcess?.terminate()
        dnsProcess?.waitUntilExit()
        dnsProcess = nil
        
        // Kill any stale processes
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killTask.arguments = ["-9", "cloudflared"]
        killTask.standardOutput = FileHandle.nullDevice
        killTask.standardError = FileHandle.nullDevice
        try? killTask.run()
        killTask.waitUntilExit()
        
        log("[DNSProxy] 🛑 DNS Proxy stopped")
        
        await MainActor.run {
            isRunning = false
            isProcessing = false
            statusMessage = "DNS Proxy Kapalı"
        }
    }
    
    func checkStatus() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", "cloudflared"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try? process.run()
        process.waitUntilExit()
        
        isRunning = process.terminationStatus == 0
        statusMessage = isRunning ? "DNS Proxy Çalışıyor" : "DNS Proxy Kapalı"
    }
    
    // MARK: - System DNS Configuration
    
    func configureSystemDNS(useLocalProxy: Bool) async throws {
        let networkService = "Wi-Fi"
        
        if useLocalProxy {
            // Set system DNS to local proxy
            try await runNetworkSetup(["-setdnsservers", networkService, "127.0.0.1"])
            log("[DNSProxy] 🌐 System DNS set to 127.0.0.1 (local proxy)")
        } else {
            // Reset to DHCP DNS
            try await runNetworkSetup(["-setdnsservers", networkService, "empty"])
            log("[DNSProxy] 🌐 System DNS reset to DHCP")
        }
    }
    
    private func runNetworkSetup(_ args: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw DNSProxyError.systemConfigFailed("networksetup failed with exit code \(process.terminationStatus)")
        }
    }
    
    // MARK: - DNS Test
    
    func testDNSResolution(domain: String = "discord.com") async -> (success: Bool, latency: Double?) {
        let start = Date()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nslookup")
        process.arguments = [domain, "127.0.0.1", "-port=\(localPort)"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let elapsed = Date().timeIntervalSince(start) * 1000
            let success = process.terminationStatus == 0
            
            return (success, success ? elapsed : nil)
        } catch {
            return (false, nil)
        }
    }
}

// MARK: - Errors

enum DNSProxyError: LocalizedError {
    case dependencyMissing(String)
    case binaryNotFound(String)
    case startFailed(String)
    case systemConfigFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .dependencyMissing(let msg): return "Bağımlılık Eksik: \(msg)"
        case .binaryNotFound(let msg): return "Binary Bulunamadı: \(msg)"
        case .startFailed(let msg): return "Başlatma Hatası: \(msg)"
        case .systemConfigFailed(let msg): return "Sistem Ayarı Hatası: \(msg)"
        }
    }
}
