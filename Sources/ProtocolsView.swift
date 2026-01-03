import SwiftUI

struct ProtocolsView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("proxyType") var proxyType: String = "socks5"
    @AppStorage("byedpiPort") var byedpiPort: String = "1080"
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("connectionTimeout") var connectionTimeout: String = "5"
    @AppStorage("maxConnections") var maxConnections: String = "512"
    @AppStorage("byedpiArgs") var byedpiArgs: String = ""
    @AppStorage("customByedpiArgs") var customByedpiArgs: String = ""
    @AppStorage("dohProvider") var dohProvider: String = "none"
    @AppStorage("splitMode") var splitMode: String = "1+s"
    @AppStorage("ttlValue") var ttlValue: String = "8"
    @AppStorage("appTheme") var appTheme: String = "dark"
    @AppStorage("activePreset") var activePreset: String = "standard"
    
    // Advanced Parameters
    @AppStorage("cacheTTL") var cacheTTL: String = "100800"
    @AppStorage("autoMode") var autoMode: String = "1"
    @AppStorage("useTFO") var useTFO: Bool = false
    @AppStorage("noUDP") var noUDP: Bool = false
    @AppStorage("defTTL") var defTTL: String = ""
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.90) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text(L("protocols.title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Proxy Type
                SettingCard(title: L("protocols.proxy_type"), icon: "network", cardBg: cardBg, textColor: textColor) {
                    HStack(spacing: 12) {
                        ForEach(["socks5", "http", "https"], id: \.self) { type in
                            Button(action: { proxyType = type }) {
                                Text(type.uppercased())
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(proxyType == type ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(proxyType == type ? .white : textColor)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Connection
                SettingCard(title: L("protocols.connection"), icon: "server.rack", cardBg: cardBg, textColor: textColor) {
                    VStack(spacing: 15) {
                        SettingRow(label: L("dashboard.config.port"), textColor: textColor) {
                            TextField("1080", text: $byedpiPort)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .onSubmit { restartIfRunning() }
                        }
                        Divider()
                        SettingRow(label: L("protocols.timeout"), textColor: textColor) {
                            TextField("30", text: $connectionTimeout)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .onSubmit { restartIfRunning() }
                        }
                        Divider()
                        SettingRow(label: L("protocols.max_conn"), textColor: textColor) {
                            TextField("100", text: $maxConnections)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .onSubmit { restartIfRunning() }
                        }
                        Divider()
                        SettingRow(label: L("dashboard.config.system_proxy"), textColor: textColor) {
                            Toggle("", isOn: $systemProxyEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                                .onChange(of: systemProxyEnabled) { newValue in
                                    if newValue { service.enableSystemProxy(port: byedpiPort) }
                                    else { service.disableSystemProxy() }
                                }
                        }
                    }
                }
                
                // DPI Bypass & Advanced Settings
                SettingCard(title: L("protocols.dpi_bypass"), icon: "shield.lefthalf.filled", cardBg: cardBg, textColor: textColor) {
                    VStack(alignment: .leading, spacing: 15) {
                        // Active Preset Display
                        HStack {
                            Text(L("dashboard.presets"))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            if let preset = PresetManager.preset(for: activePreset) {
                                HStack(spacing: 6) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 12))
                                    Text(preset.localizedName)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            }
                        }
                        
                        Divider()
                        
                        // TTL Settings
                        SettingRow(label: L("protocols.ttl"), textColor: textColor) {
                            TextField("8", text: $ttlValue)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onSubmit { restartIfRunning() }
                        }
                        
                        Divider()
                        
                        // Timeout
                        SettingRow(label: L("protocols.timeout"), textColor: textColor) {
                            TextField("5", text: $connectionTimeout)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .onSubmit { restartIfRunning() }
                        }
                        
                        Divider()
                        
                        // Cache TTL
                        SettingRow(label: "Cache TTL (s)", textColor: textColor) {
                            TextField("100800", text: $cacheTTL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .onSubmit { restartIfRunning() }
                        }
                        
                        Divider()
                        
                        // Auto Mode
                        SettingRow(label: "Auto Mode", textColor: textColor) {
                            Picker("", selection: $autoMode) {
                                Text("0").tag("0")
                                Text("1").tag("1")
                                Text("2").tag("2")
                                Text("3").tag("3")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 150)
                        }
                        
                        Divider()
                        
                        // Toggles Row
                        HStack(spacing: 30) {
                            Toggle("TCP Fast Open", isOn: $useTFO)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                            
                            Toggle("No UDP", isOn: $noUDP)
                                .toggleStyle(SwitchToggleStyle(tint: .orange))
                        }
                        .font(.subheadline)
                        .foregroundColor(textColor)
                        
                        Divider()
                        
                        // Default TTL (optional)
                        SettingRow(label: "Default TTL", textColor: textColor) {
                            TextField("(auto)", text: $defTTL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 70)
                                .onSubmit { restartIfRunning() }
                        }
                        
                        // Custom Args (only for custom preset)
                        if activePreset == "custom" {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L("protocols.custom_args"))
                                    .foregroundColor(textColor)
                                TextField("--split 1+s --disorder 1", text: $customByedpiArgs)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 12, design: .monospaced))
                                    .onSubmit { restartIfRunning() }
                            }
                        }
                    }
                }
                
                // DNS
                SettingCard(title: L("protocols.dns"), icon: "globe", cardBg: cardBg, textColor: textColor) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        DNSBtn(name: "Kapalı", ip: L("settings.language.system"), provider: "none", selected: $dohProvider, textColor: textColor)
                        DNSBtn(name: "Cloudflare", ip: "1.1.1.1", provider: "cloudflare", selected: $dohProvider, textColor: textColor)
                        DNSBtn(name: "Google", ip: "8.8.8.8", provider: "google", selected: $dohProvider, textColor: textColor)
                        DNSBtn(name: "Quad9", ip: "9.9.9.9", provider: "quad9", selected: $dohProvider, textColor: textColor)
                    }
                }
            }
            .padding(30)
        }
        .background(bgColor)
        // Reactive Logic
        .onChange(of: proxyType) { _ in restartIfRunning() }
        .onChange(of: dohProvider) { _ in restartIfRunning() }
        .onChange(of: splitMode) { _ in restartIfRunning() } // If splitMode changed externally
        .onChange(of: autoMode) { _ in restartIfRunning() }
        .onChange(of: useTFO) { _ in restartIfRunning() }
        .onChange(of: noUDP) { _ in restartIfRunning() }
    }
    
    private func restartIfRunning() {
        if service.isRunning {
             service.restartService()
        }
    }
}

struct SettingCard<Content: View>: View {
    let title: String
    let icon: String
    let cardBg: Color
    let textColor: Color
    let content: Content
    
    init(title: String, icon: String, cardBg: Color, textColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.cardBg = cardBg
        self.textColor = textColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(.blue)
                Text(title).font(.headline).foregroundColor(textColor)
            }
            content
                .padding(20)
                .background(cardBg)
                .cornerRadius(12)
        }
    }
}

struct SettingRow<Content: View>: View {
    let label: String
    let textColor: Color
    let control: Content
    
    init(label: String, textColor: Color, @ViewBuilder control: () -> Content) {
        self.label = label
        self.textColor = textColor
        self.control = control()
    }
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(textColor)
            Spacer()
            control
        }
    }
}

struct DNSBtn: View {
    let name: String
    let ip: String
    let provider: String
    @Binding var selected: String
    let textColor: Color
    
    var body: some View {
        Button(action: { selected = provider }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name).font(.subheadline).foregroundColor(textColor)
                    Text(ip).font(.caption).foregroundColor(.gray)
                }
                Spacer()
                if selected == provider {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(selected == provider ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
