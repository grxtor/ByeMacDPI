import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("appTheme") var appTheme: String = "dark"
    @AppStorage("autoConnect") var autoConnect: Bool = false
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.90) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Ayarlar")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Theme
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintbrush.fill").foregroundColor(.blue)
                        Text("Tema").font(.headline).foregroundColor(textColor)
                    }
                    
                    HStack(spacing: 12) {
                        ThemeCard(title: "Karanlık", icon: "moon.fill", isSelected: appTheme == "dark", textColor: textColor) {
                            appTheme = "dark"
                        }
                        ThemeCard(title: "Aydınlık", icon: "sun.max.fill", isSelected: appTheme == "light", textColor: textColor) {
                            appTheme = "light"
                        }
                        ThemeCard(title: "Şeffaf", icon: "sparkles", isSelected: appTheme == "transparent", textColor: textColor) {
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
                        Text("Başlangıç").font(.headline).foregroundColor(textColor)
                    }
                    
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Giriş Sırasında Başlat")
                                    .foregroundColor(textColor)
                                Text("macOS açıldığında ByeMacDPI servisini başlat")
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
                                Text("Otomatik Bağlan")
                                    .foregroundColor(textColor)
                                Text("Uygulama açıldığında servisi başlat")
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
                
                // About
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundColor(.blue)
                        Text("Hakkında").font(.headline).foregroundColor(textColor)
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ByeMacDPI")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(textColor)
                                Text("Versiyon 2.0")
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
                            Text("macOS için DPI Bypass aracı")
                                .font(.subheadline)
                                .foregroundColor(textColor.opacity(0.8))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                Link("github.com/grxtor/ByeMacDPI", destination: URL(string: "https://github.com/grxtor/ByeMacDPI")!)
                                    .font(.caption)
                            }
                            
                            Text("MIT Lisansı ile açık kaynak")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
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
