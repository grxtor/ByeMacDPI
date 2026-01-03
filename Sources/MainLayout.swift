import SwiftUI

struct MainLayout: View {
    @EnvironmentObject var service: ServiceManager
    @State private var selectedTab: String? = "dashboard"
    @AppStorage("appTheme") var appTheme: String = "dark"
    
    var backgroundColor: Color {
        switch appTheme {
        case "light": return Color(white: 0.95)
        case "dark": return Color(white: 0.08)
        case "transparent": return Color.clear
        default: return Color(white: 0.08)
        }
    }
    
    var textColor: Color {
        appTheme == "light" ? .black : .white
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            NavigationSplitView {
                VStack(spacing: 0) {
                    // Navigation List
                    List(selection: $selectedTab) {
                        Section(header: Text(L("sidebar.general")).foregroundColor(.gray)) {
                            NavigationLink(value: "dashboard") {
                                Label(L("dashboard.title"), systemImage: "gauge.with.dots.needle.bottom.50percent")
                            }
                            NavigationLink(value: "library") {
                                Label(L("library.title"), systemImage: "square.grid.2x2.fill")
                            }
                        }
                        
                        Section(header: Text(L("sidebar.config")).foregroundColor(.gray)) {
                            NavigationLink(value: "protocols") {
                                Label(L("protocols.title"), systemImage: "arrow.triangle.branch")
                            }
                            NavigationLink(value: "dns") {
                                Label(L("onboarding.step2"), systemImage: "network")
                            }
                        }
                        
                        Section(header: Text(L("sidebar.system")).foregroundColor(.gray)) {
                            NavigationLink(value: "settings") {
                                Label(L("settings.title"), systemImage: "gearshape.fill")
                            }
                        }
                    }
                    .listStyle(SidebarListStyle())
                    
                    Divider()
                    
                    // Quick Theme Toggle at Bottom
                    HStack(spacing: 8) {
                        ThemeToggleButton(icon: "moon.fill", isActive: appTheme == "dark") {
                            appTheme = "dark"
                        }
                        ThemeToggleButton(icon: "sun.max.fill", isActive: appTheme == "light") {
                            appTheme = "light"
                        }
                        ThemeToggleButton(icon: "sparkles", isActive: appTheme == "transparent") {
                            appTheme = "transparent"
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .navigationTitle("ByeMacDPI")
            } detail: {
                ZStack(alignment: .top) {
                    Group {
                        switch selectedTab {
                        case "dashboard": DashboardView(service: service)
                        case "library": AppLibraryView(service: service)
                        case "protocols": ProtocolsView(service: service)
                        case "dns": DNSToolsView(service: service)
                        case "settings": SettingsView(service: service)
                        default: DashboardView(service: service)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                    
                    // Custom Top Bar for Detail View
                    TopBar(title: getTitle(for: selectedTab), theme: appTheme)
                }
            }
            .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
            .preferredColorScheme(appTheme == "light" ? .light : .dark)
        }
    }
    func getTitle(for tab: String?) -> String {
        switch tab {
        case "dashboard": return L("dashboard.title")
        case "library": return L("library.title")
        case "protocols": return L("protocols.title")
        case "dns": return L("onboarding.step2")
        case "settings": return L("settings.title")
        default: return L("dashboard.title")
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct TopBar: View {
    let title: String
    let theme: String
    
    var body: some View {
        // Simple spacer for top padding - native window controls are used
        Rectangle()
            .fill(Color.clear)
            .frame(height: 28)
    }
}



struct ThemeToggleButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .white : .gray)
                .frame(width: 32, height: 32)
                .background(isActive ? Color.blue : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
