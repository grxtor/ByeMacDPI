import SwiftUI

struct DashboardView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("savedApps") var savedAppsData: Data = Data()
    @AppStorage("proxyType") var proxyType: String = "socks5"
    @AppStorage("byedpiPort") var byedpiPort: String = "1080"
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("splitMode") var splitMode: String = "1+s"
    @AppStorage("activePreset") var activePreset: String = "standard"
    @AppStorage("appTheme") var appTheme: String = "dark"
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.90) : Color(white: 0.11) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                Text(L("dashboard.title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Main Control Card
                VStack(spacing: 0) {
                    HStack(spacing: 25) {
                        // Power Button
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                service.toggleService()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(service.isRunning ? Color.green : Color(white: appTheme == "light" ? 0.8 : 0.2))
                                    .frame(width: 70, height: 70)
                                    .shadow(color: service.isRunning ? .green.opacity(0.4) : .clear, radius: 12)
                                
                                Image(systemName: "power")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(service.isRunning ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(service.isRunning ? L("dashboard.active") : L("dashboard.inactive"))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(textColor)
                            }
                            
                            if service.isRunning {
                                Text("\(proxyType.uppercased())://127.0.0.1:\(byedpiPort)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.blue)
                            } else {
                                Text(L("dashboard.start_hint"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        if service.isRunning {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatTime(service.connectionTime))
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                                Text("Uptime")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(25)
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Config Row
                    HStack(spacing: 0) {
                        ConfigItem(label: L("dashboard.config.protocol"), textColor: textColor) {
                            Picker("", selection: $proxyType) {
                                Text("SOCKS5").tag("socks5")
                                Text("HTTP").tag("http")
                                Text("HTTPS").tag("https")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }
                        
                        Divider().frame(height: 40)
                        
                        ConfigItem(label: L("dashboard.config.port"), textColor: textColor) {
                            TextField("", text: $byedpiPort)
                                .textFieldStyle(PlainTextFieldStyle())
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .foregroundColor(textColor)
                        }
                        
                        Divider().frame(height: 40)
                        
                        ConfigItem(label: L("dashboard.config.split"), textColor: textColor) {
                            Picker("", selection: $splitMode) {
                                Text("1+s").tag("1+s")
                                Text("2+s").tag("2+s")
                                Text("fake").tag("fake")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .labelsHidden()
                        }
                        
                        Divider().frame(height: 40)
                        
                        ConfigItem(label: L("dashboard.config.system_proxy"), textColor: textColor) {
                            Toggle("", isOn: $systemProxyEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .onChange(of: systemProxyEnabled) { newValue in
                                    if newValue { service.enableSystemProxy(port: byedpiPort) }
                                    else { service.disableSystemProxy() }
                                }
                        }
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 10)
                }
                .background(cardBg)
                .cornerRadius(16)
                
                // Presets
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("dashboard.presets"))
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 10) {
                        CompactPreset(name: L("preset.standard"), icon: "shield", isActive: activePreset == "standard", textColor: textColor) {
                            activePreset = "standard"; proxyType = "socks5"; splitMode = "1+s"
                        }
                        CompactPreset(name: L("preset.game"), icon: "gamecontroller", isActive: activePreset == "gaming", textColor: textColor) {
                            activePreset = "gaming"; proxyType = "socks5"; splitMode = "fake"
                        }
                        CompactPreset(name: L("preset.streaming"), icon: "play.tv", isActive: activePreset == "streaming", textColor: textColor) {
                            activePreset = "streaming"; proxyType = "http"; splitMode = "2+s"
                        }
                        CompactPreset(name: L("preset.privacy"), icon: "eye.slash", isActive: activePreset == "privacy", textColor: textColor) {
                            activePreset = "privacy"; proxyType = "https"; splitMode = "1+s"
                        }
                    }
                }
                
                // Quick Launch
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("dashboard.apps"))
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(loadApps().prefix(6)) { app in
                                AppGridItem(name: app.name, path: app.path, fallbackIcon: "app.fill", color: .blue) {
                                    launchApp(app)
                                }
                            }
                        }
                    }
                }
            }
            .padding(30)
        }
        .background(bgColor)
    }
    
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", app.path, "--args"] + app.customArgs.split(separator: " ").map(String.init).filter { $0 != "--args" }
        do {
            try task.run()
        } catch {
            print("Failed to launch app: \(error)")
        }
    }
}

struct ConfigItem<Content: View>: View {
    let label: String
    let textColor: Color
    let control: Content
    
    init(label: String, textColor: Color, @ViewBuilder control: () -> Content) {
        self.label = label
        self.textColor = textColor
        self.control = control()
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            control
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompactPreset: View {
    let name: String
    let icon: String
    let isActive: Bool
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(name)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(isActive ? .white : textColor.opacity(0.7))
            .background(isActive ? Color.blue : Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
