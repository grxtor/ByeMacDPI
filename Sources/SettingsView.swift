import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("appTheme") var appTheme: String = "dark"
    @AppStorage("autoConnect") var autoConnect: Bool = false
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.90) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text(L("settings.title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Language
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe").foregroundColor(.blue)
                        Text(L("settings.language")).font(.headline).foregroundColor(textColor)
                    }
                    
                    HStack(spacing: 12) {
                        ThemeCard(title: L("settings.language.system"), icon: "gear", isSelected: loc.appLanguage == "system", textColor: textColor) {
                            loc.setLanguage("system")
                        }
                        ThemeCard(title: L("settings.language.tr"), icon: "character.book.closed", isSelected: loc.appLanguage == "tr", textColor: textColor) {
                            loc.setLanguage("tr")
                        }
                        ThemeCard(title: L("settings.language.en"), icon: "character.book.closed.fill", isSelected: loc.appLanguage == "en", textColor: textColor) {
                            loc.setLanguage("en")
                        }
                    }
                    .padding(20)
                    .background(cardBg)
                    .cornerRadius(12)
                }
                
                // Theme
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintbrush.fill").foregroundColor(.blue)
                        Text(L("settings.theme")).font(.headline).foregroundColor(textColor)
                    }
                    
                    HStack(spacing: 12) {
                        ThemeCard(title: L("settings.theme.dark"), icon: "moon.fill", isSelected: appTheme == "dark", textColor: textColor) {
                            appTheme = "dark"
                        }
                        ThemeCard(title: L("settings.theme.light"), icon: "sun.max.fill", isSelected: appTheme == "light", textColor: textColor) {
                            appTheme = "light"
                        }
                        ThemeCard(title: L("settings.theme.transparent"), icon: "sparkles", isSelected: appTheme == "transparent", textColor: textColor) {
                            appTheme = "transparent"
                        }
                    }
                    .padding(20)
                    .background(cardBg)
                    .cornerRadius(12)
                }
                
                // Startup
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "power").foregroundColor(.blue)
                        Text(L("settings.startup")).font(.headline).foregroundColor(textColor)
                    }
                    
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(L("settings.startup.login"))
                                    .foregroundColor(textColor)
                                Text(L("settings.startup.login_desc"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { service.autoStartEnabled },
                                set: { _ in service.toggleAutoStart() }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .labelsHidden()
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text(L("settings.startup.auto_connect"))
                                    .foregroundColor(textColor)
                                Text(L("settings.startup.auto_connect_desc"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Toggle("", isOn: $autoConnect)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                        }
                    }
                    .padding(20)
                    .background(cardBg)
                    .cornerRadius(12)
                }
                
                // Customization
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.2.fill").foregroundColor(.blue)
                        Text(L("settings.customization")).font(.headline).foregroundColor(textColor)
                    }
                    
                    VStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("settings.customization.binary_path"))
                                .foregroundColor(textColor)
                            Text(service.binaryPath)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(6)
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                let panel = NSOpenPanel()
                                panel.allowsMultipleSelection = false
                                panel.canChooseDirectories = false
                                panel.canChooseFiles = true
                                if panel.runModal() == .OK {
                                    if let url = panel.url {
                                        UserDefaults.standard.set(url.path, forKey: "customBinaryPath")
                                        // Refresh service
                                        service.stopService()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            service.checkStatus()
                                        }
                                    }
                                }
                            }) {
                                Text(L("settings.customization.change"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                service.revealInFinder()
                            }) {
                                Text(L("settings.customization.open_folder"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(Color.gray.opacity(0.15))
                                    .foregroundColor(textColor)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                    .background(cardBg)
                    .cornerRadius(12)
                }
                
                // About
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundColor(.blue)
                        Text(L("settings.about")).font(.headline).foregroundColor(textColor)
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ByeMacDPI")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(textColor)
                                Text("\(L("settings.about.version")) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("settings.about.desc"))
                                .font(.subheadline)
                                .foregroundColor(textColor.opacity(0.8))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                Link("github.com/grxtor/ByeMacDPI", destination: URL(string: "https://github.com/grxtor/ByeMacDPI")!)
                                    .font(.caption)
                            }
                            
                            Text(L("settings.about.license"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        Button(action: {
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text(L("settings.about.reset"))
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(cardBg)
                    .cornerRadius(12)
                }
            }
            .padding(30)
        }
        .background(bgColor)
    }
}

struct ThemeCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .foregroundColor(isSelected ? .white : textColor)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
