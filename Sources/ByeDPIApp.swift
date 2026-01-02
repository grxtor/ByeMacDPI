import SwiftUI
import AppKit

@main
struct ByeDPIApp: App {
    @StateObject private var service = ServiceManager()
    
    var body: some Scene {
        WindowGroup {
            MainLayout()
                .environmentObject(service) // Optional, but good practice
                .frame(minWidth: 900, minHeight: 650)
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
