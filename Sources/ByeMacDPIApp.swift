import SwiftUI
import AppKit

@main
struct ByeMacDPIApp: App {
    @StateObject private var service = ServiceManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainLayout()
                    .environmentObject(service)
                    .frame(minWidth: 900, minHeight: 650)
                
                // Show onboarding overlay on first run
                if showOnboarding {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                    
                    OnboardingView(service: service, isComplete: $hasCompletedOnboarding)
                        .cornerRadius(16)
                        .shadow(radius: 20)
                }
            }
            .onAppear {
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .onChange(of: hasCompletedOnboarding) { newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showOnboarding = false
                    }
                } else {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showOnboarding = true
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        MenuBarExtra("ByeMacDPI", systemImage: service.isRunning ? "bolt.fill" : "bolt.slash.fill") {
            VStack {
                Text("ByeMacDPI")
                    .font(.headline)
                Divider()
                Button(service.isRunning ? "Durdur" : "Başlat") {
                    service.toggleService()
                }
                Button("Discord Başlat") {
                    service.launchDiscord()
                }
                Divider()
                Button("Uygulamayı Göster") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                Button("Çıkış") {
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
        
        // 2. Kill Service Forcefully (Synchronous)
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        kill.arguments = ["-9", "ciadpi"]
        // Silent
        kill.standardOutput = FileHandle.nullDevice
        kill.standardError = FileHandle.nullDevice
        try? kill.run()
        kill.waitUntilExit()
    }
}
