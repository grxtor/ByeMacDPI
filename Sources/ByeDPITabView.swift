import SwiftUI

// MARK: - ByeDPI Tab View (SplitWire Style)
struct ByeDPITabView: View {
    @EnvironmentObject var service: ServiceManager
    @EnvironmentObject var dependencyManager: DependencyManager
    
    @AppStorage("savedApps") var savedAppsData: Data = Data()
    @AppStorage("activePreset") var activePreset: String = "standard"
    @AppStorage("appTheme") var appTheme: String = "dark"
    
    @State private var showAddApp = false
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.92) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.06) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Engine Selector
                engineSelector
                
                // Status Card
                statusCard
                
                // Quick Actions
                quickActionsSection
                
                // Action Buttons
                actionButtons
                
                // Presets (Only for ByeDPI as SpoofDPI is more automatic)
                if service.selectedEngine == .byedpi {
                    presetsSection
                }
            }
            .padding(24)
        }
        .background(bgColor)
    }
    
    // MARK: - Engine Selector
    var engineSelector: some View {
        HStack(spacing: 8) {
            ForEach(ProxyEngineType.allCases, id: \.self) { engine in
                Button(action: { 
                    if service.selectedEngine != engine {
                        service.stopService {
                            service.selectedEngine = engine
                        }
                    }
                }) {
                    Text(engine.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(service.selectedEngine == engine ? Color.blue : cardBg)
                        .foregroundColor(service.selectedEngine == engine ? .white : textColor)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(cardBg.opacity(0.5))
        .cornerRadius(10)
    }
    
    // MARK: - Status Card
    var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: service.selectedEngine == .byedpi ? "shield.checkered" : "bolt.shield")
                    .foregroundColor(.blue)
                Text("\(service.selectedEngine.displayName) Durumu")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !dependencyManager.isInstalled(service.selectedEngine.dependency) {
                    Text("⚠️ Kurulu Değil")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Status Row
                HStack {
                    Text("Durum:")
                        .foregroundColor(textColor.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(service.isRunning ? Color.green : (service.isProcessing ? Color.yellow : Color.red))
                            .frame(width: 10, height: 10)
                        
                        Text(service.isRunning ? "Çalışıyor" : (service.isProcessing ? "İşleniyor..." : "Kapalı"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(service.isRunning ? .green : (service.isProcessing ? .yellow : textColor.opacity(0.5)))
                    }
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Proxy Address
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(service.selectedEngine == .byedpi ? "SOCKS5" : "HTTP") Proxy Adresi:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("127.0.0.1:\(service.byedpiPort)")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
                
                // Uptime
                if service.isRunning {
                    Divider().background(Color.gray.opacity(0.3))
                    
                    HStack {
                        Text("Çalışma Süresi:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(formatTime(service.connectionTime))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(20)
            .background(cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Quick Actions
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Hızlı İşlemler")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: { showAddApp = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // App Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(loadApps().prefix(8)) { app in
                    QuickAppButton(
                        app: app,
                        cardBg: cardBg,
                        textColor: textColor,
                        isServiceRunning: service.isRunning
                    ) {
                        launchApp(app)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    var actionButtons: some View {
        HStack(spacing: 12) {
            // Start/Stop Button
            Button(action: { service.toggleService() }) {
                HStack {
                    if service.isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: service.isRunning ? "stop.fill" : "play.fill")
                    }
                    Text(service.isRunning ? "Durdur" : "Başlat")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(service.isRunning ? Color.red.opacity(0.9) : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(service.isProcessing || !dependencyManager.isInstalled(service.selectedEngine.dependency))
            
            // Stop All Button
            Button(action: { service.stopAllServices() }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Tümünü Kapat")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            
            // System Proxy Button
            Button(action: toggleSystemProxy) {
                HStack {
                    Image(systemName: "globe")
                    Text("Sistem Proxy")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(service.systemProxyEnabled ? Color.blue : cardBg)
                .foregroundColor(service.systemProxyEnabled ? .white : textColor)
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Presets Section
    var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.purple)
                Text("Önceden Hazır Ayarlar")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(BypassStrategy.allCases) { strategy in
                    let preset = BypassPreset(strategy: strategy)
                    PresetButton(
                        preset: preset,
                        isActive: activePreset == strategy.id,
                        cardBg: cardBg,
                        textColor: textColor
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            activePreset = strategy.id
                            if service.isRunning {
                                service.stopService {
                                    service.startService()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    
    func loadApps() -> [AppItem] {
        (try? JSONDecoder().decode([AppItem].self, from: savedAppsData)) ?? []
    }
    
    func launchApp(_ app: AppItem) {
        let port = service.byedpiPort
        let proxyType = service.selectedEngine == .byedpi ? "socks5" : "http"
        var args = ["-a", app.path, "--args", "--proxy-server=\(proxyType)://127.0.0.1:\(port)"]
        
        if !app.customArgs.isEmpty {
            args += app.customArgs.split(separator: " ").map(String.init)
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = args
        try? task.run()
    }
    
    func toggleSystemProxy() {
        if service.systemProxyEnabled {
            service.disableSystemProxy()
            service.systemProxyEnabled = false
        } else {
            service.enableSystemProxy(port: service.byedpiPort)
            service.systemProxyEnabled = true
        }
    }
}

// MARK: - Quick App Button
struct QuickAppButton: View {
    let app: AppItem
    let cardBg: Color
    let textColor: Color
    let isServiceRunning: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var appIcon: NSImage?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // App Icon
                Group {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 40, height: 40)
                
                Text(app.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(isHovered ? cardBg.opacity(1.5) : cardBg)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isServiceRunning ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear { loadAppIcon() }
    }
    
    func loadAppIcon() {
        let url = URL(fileURLWithPath: app.path)
        appIcon = NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let preset: BypassPreset
    let isActive: Bool
    let cardBg: Color
    let textColor: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .white : .blue)
                
                Text(preset.localizedName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? .white : textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.blue : (isHovered ? cardBg.opacity(1.2) : cardBg))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
