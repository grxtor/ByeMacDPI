import SwiftUI

// MARK: - Tab Definition
enum AppTab: String, CaseIterable, Identifiable {
    case byedpi = "byedpi"
    case dns = "dns"
    case network = "network"
    case about = "about"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .byedpi: return "ByeDPI"
        case .dns: return "DNS"
        case .network: return "Ağ Ayarları"
        case .about: return "Hakkında"
        }
    }
    
    var icon: String {
        switch self {
        case .byedpi: return "shield.checkered"
        case .dns: return "network"
        case .network: return "gear"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Tab Navigation View
struct TabNavigationView: View {
    @State private var selectedTab: AppTab = .byedpi
    @StateObject private var service = ServiceManager.shared
    @StateObject private var dnsManager = DNSProxyManager.shared
    @StateObject private var dependencyManager = DependencyManager.shared
    
    @AppStorage("appTheme") var appTheme: String = "dark"
    @AppStorage("appLanguage") var appLanguage: String = "system"
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.06) }
    var tabBg: Color { appTheme == "light" ? Color(white: 0.88) : Color(white: 0.12) }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Tab Bar
            tabBarView
            
            // Content
            TabView(selection: $selectedTab) {
                ByeDPITabView()
                    .environmentObject(service)
                    .environmentObject(dependencyManager)
                    .tag(AppTab.byedpi)
                
                DNSTabView()
                    .environmentObject(dnsManager)
                    .environmentObject(dependencyManager)
                    .tag(AppTab.dns)
                
                NetworkSettingsView()
                    .environmentObject(service)
                    .tag(AppTab.network)
                
                AboutView()
                    .tag(AppTab.about)
            }
            .tabViewStyle(.automatic)
        }
        .background(bgColor)
        .preferredColorScheme(appTheme == "light" ? .light : .dark)
    }
    
    // MARK: - Header
    var headerView: some View {
        HStack {
            // Title
            Text("ByeMacDPI")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(textColor)
            
            Text("v2.0")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            Spacer()
            
            // Language Picker
            Picker("", selection: $appLanguage) {
                Text("🇹🇷 Türkçe").tag("tr")
                Text("🇬🇧 English").tag("en")
                Text("🌐 System").tag("system")
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 120)
            
            // Theme Toggle
            HStack(spacing: 4) {
                ThemeButton(icon: "moon.fill", isActive: appTheme == "dark") {
                    withAnimation { appTheme = "dark" }
                }
                ThemeButton(icon: "sun.max.fill", isActive: appTheme == "light") {
                    withAnimation { appTheme = "light" }
                }
            }
            .padding(4)
            .background(tabBg)
            .cornerRadius(8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(bgColor)
    }
    
    // MARK: - Tab Bar
    var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    textColor: textColor,
                    bgColor: tabBg
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(tabBg.opacity(0.5))
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let textColor: Color
    let bgColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : textColor.opacity(0.7))
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Theme Button
struct ThemeButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isActive ? .white : .gray)
                .frame(width: 28, height: 28)
                .background(isActive ? Color.blue : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Network Settings View (Placeholder)
struct NetworkSettingsView: View {
    @EnvironmentObject var service: ServiceManager
    @AppStorage("appTheme") var appTheme: String = "dark"
    @AppStorage("byedpiPort") var byedpiPort: String = "1080"
    @AppStorage("systemProxyEnabled") var systemProxyEnabled: Bool = false
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.92) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.06) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Ağ Ayarları")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Proxy Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Proxy Ayarları")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text("SOCKS5 Port:")
                            .foregroundColor(textColor)
                        TextField("", text: $byedpiPort)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .padding()
                    .background(cardBg)
                    .cornerRadius(12)
                    
                    Toggle(isOn: $systemProxyEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sistem Proxy")
                                .foregroundColor(textColor)
                            Text("Wi-Fi için otomatik SOCKS5 proxy ayarla")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding()
                    .background(cardBg)
                    .cornerRadius(12)
                    .onChange(of: systemProxyEnabled) { newValue in
                        if newValue {
                            service.enableSystemProxy(port: byedpiPort)
                        } else {
                            service.disableSystemProxy()
                        }
                    }
                }
                
                // Danger Zone
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tehlikeli Bölge")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Uygulama Verilerini Sıfırla")
                            .foregroundColor(textColor)
                        
                        Text("İndirilen tüm binary dosyalarını ve ayarları siler. Uygulama bir sonraki açılışta yeniden kurulum gerektirecektir.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            service.stopAllServices()
                            try? DependencyManager.shared.wipe()
                            // Force app exit or notify user
                            NSApp.terminate(nil)
                        }) {
                            Text("Tümünü Sil ve Kapat")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(cardBg)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(30)
        }
        .background(bgColor)
    }
}

// MARK: - About View
struct AboutView: View {
    @AppStorage("appTheme") var appTheme: String = "dark"
    @StateObject private var dependencyManager = DependencyManager.shared
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.92) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.06) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // App Icon and Info
                VStack(spacing: 16) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("ByeMacDPI")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(textColor)
                    
                    Text("v2.0.0")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Text("macOS için DPI Bypass Aracı")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Installed Components
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kurulu Bileşenler")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    ForEach(Dependency.allCases) { dep in
                        HStack {
                            Image(systemName: dep.icon)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(dep.displayName)
                                    .foregroundColor(textColor)
                                if let version = dependencyManager.getInstalledVersion(dep) {
                                    Text(version)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if dependencyManager.isInstalled(dep) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("Kurulu Değil")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(cardBg)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 60)
                
                // Links
                HStack(spacing: 20) {
                    Link(destination: URL(string: "https://github.com/grxtor/ByeMacDPI")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(cardBg)
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    
                    Link(destination: URL(string: "https://github.com/hufrea/byedpi")!) {
                        HStack {
                            Image(systemName: "shield")
                            Text("ByeDPI")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(cardBg)
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
                
                Text("GPL v3 License")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
        }
        .background(bgColor)
    }
}

