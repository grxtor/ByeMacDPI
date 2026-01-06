import SwiftUI
import AppKit

@main
struct ByeMacDPIApp: App {
    @StateObject private var service = ServiceManager.shared
    @StateObject private var dependencyManager = DependencyManager.shared
    @StateObject private var dnsManager = DNSProxyManager.shared
    
    @AppStorage("setupCompleted") private var setupCompleted = false
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !setupCompleted || !dependencyManager.allRequiredInstalled() {
                    // Show setup wizard if not completed or dependencies missing
                    SetupWizardView()
                        .frame(minWidth: 600, minHeight: 500)
                } else {
                    // Main app with tab navigation
                    TabNavigationView()
                        .frame(minWidth: 800, minHeight: 600)
                }
            }
            .onAppear {
                // Check for updates in background
                Task {
                    await dependencyManager.checkForUpdates()
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        MenuBarExtra("ByeMacDPI", systemImage: service.isRunning ? "shield.checkered" : "shield.slash") {
            VStack {
                HStack {
                    Circle()
                        .fill(service.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text("ByeMacDPI")
                        .font(.headline)
                }
                
                Divider()
                
                Button(service.isRunning ? "🛑 Durdur" : "▶️ Başlat") {
                    service.toggleService()
                }
                
                if dnsManager.isRunning {
                    Button("🌐 DNS Proxy Durdur") {
                        Task { await dnsManager.stopDNSProxy() }
                    }
                }
                
                Divider()
                
                Button("💬 Discord Başlat") {
                    if !service.isRunning { service.startService() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        service.launchDiscord()
                    }
                }
                
                Divider()
                
                Button("📱 Uygulamayı Göster") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                
                Button("🚪 Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("[ByeMacDPI] 🚨 Application terminating, cleaning up...")
        
        // 1. Disable System Proxy (Synchronous)
        ServiceManager.shared.disableSystemProxy()
        
        // 2. Kill all binary engines forcefully
        let binaries = ["ciadpi", "cloudflared", "spoof-dpi"]
        for binary in binaries {
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["-9", binary]
            killTask.standardOutput = FileHandle.nullDevice
            killTask.standardError = FileHandle.nullDevice
            try? killTask.run()
            killTask.waitUntilExit()
        }
    }
}
