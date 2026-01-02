import SwiftUI

struct ProtocolsView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("proxyType") var proxyType: String = "socks5"
    @AppStorage("byedpiPort") var byedpiPort: String = "1080"
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    @AppStorage("connectionTimeout") var connectionTimeout: String = "30"
    @AppStorage("maxConnections") var maxConnections: String = "100"
    @AppStorage("byedpiArgs") var byedpiArgs: String = "-r 1+s"
    @AppStorage("dohProvider") var dohProvider: String = "none"
    @AppStorage("splitMode") var splitMode: String = "1+s"
    @AppStorage("ttlValue") var ttlValue: String = "4"
    @AppStorage("appTheme") var appTheme: String = "dark"
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.90) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Protokol Ayarları")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Proxy Type
                SettingCard(title: "Proxy Türü", icon: "network", cardBg: cardBg, textColor: textColor) {
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
                SettingCard(title: "Bağlantı", icon: "server.rack", cardBg: cardBg, textColor: textColor) {
                    VStack(spacing: 15) {
                        SettingRow(label: "Port", textColor: textColor) {
                            TextField("1080", text: $byedpiPort)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }
                        Divider()
                        SettingRow(label: "Zaman Aşımı (sn)", textColor: textColor) {
                            TextField("30", text: $connectionTimeout)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }
                        Divider()
                        SettingRow(label: "Maks. Bağlantı", textColor: textColor) {
                            TextField("100", text: $maxConnections)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }
                        Divider()
                        SettingRow(label: "Sistem Proxy", textColor: textColor) {
                            Toggle("", isOn: $systemProxyEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                                .onChange(of: systemProxyEnabled) { oldValue, newValue in
                                    if newValue { service.enableSystemProxy(port: byedpiPort) }
                                    else { service.disableSystemProxy() }
                                }
                        }
                    }
                }
                
                // DPI Bypass
                SettingCard(title: "DPI Bypass", icon: "shield.lefthalf.filled", cardBg: cardBg, textColor: textColor) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Split Modu")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        HStack(spacing: 10) {
                            ForEach(["1+s", "2+s", "3+s", "fake"], id: \.self) { mode in
                                Button(action: { splitMode = mode }) {
                                    Text(mode)
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(splitMode == mode ? Color.purple : Color.gray.opacity(0.2))
                                        .foregroundColor(splitMode == mode ? .white : textColor)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Divider()
                        
                        SettingRow(label: "TTL Değeri", textColor: textColor) {
                            TextField("4", text: $ttlValue)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Özel Argümanlar")
                                .foregroundColor(textColor)
                            TextField("-r 1+s", text: $byedpiArgs)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                // DNS
                SettingCard(title: "DNS over HTTPS", icon: "globe", cardBg: cardBg, textColor: textColor) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        DNSBtn(name: "Kapalı", ip: "Sistem", provider: "none", selected: $dohProvider, textColor: textColor)
                        DNSBtn(name: "Cloudflare", ip: "1.1.1.1", provider: "cloudflare", selected: $dohProvider, textColor: textColor)
                        DNSBtn(name: "Google", ip: "8.8.8.8", provider: "google", selected: $dohProvider, textColor: textColor)
                        DNSBtn(name: "Quad9", ip: "9.9.9.9", provider: "quad9", selected: $dohProvider, textColor: textColor)
                    }
                }
            }
            .padding(30)
        }
        .background(bgColor)
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
