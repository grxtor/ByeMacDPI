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
                        Section(header: Text("Genel").foregroundColor(.gray)) {
                            NavigationLink(value: "dashboard") {
                                Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                            }
                            NavigationLink(value: "library") {
                                Label("Uygulamalar", systemImage: "square.grid.2x2.fill")
                            }
                        }
                        
                        Section(header: Text("Yapılandırma").foregroundColor(.gray)) {
                            NavigationLink(value: "protocols") {
                                Label("Protokoller", systemImage: "arrow.triangle.branch")
                            }
                            NavigationLink(value: "dns") {
                                Label("DNS Tester", systemImage: "network")
                            }
                        }
                        
                        Section(header: Text("Sistem").foregroundColor(.gray)) {
                            NavigationLink(value: "settings") {
                                Label("Ayarlar", systemImage: "gearshape.fill")
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
                .navigationTitle("ByeDPI")
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
                    TopBar(title: (selectedTab ?? "dashboard").capitalized, theme: appTheme)
                }
            }
            .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
            .preferredColorScheme(appTheme == "light" ? .light : .dark)
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
        HStack {
            Spacer()
            
            // Draggable Area
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                )
            
            Spacer()
        }
        .frame(height: 40)
        .overlay(
            HStack {
                Spacer()
                // Window Controls could go here if we were doing a completely custom title bar
                // But for now, let's just make it a draggable buffer
            }
        )
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
