import SwiftUI
import AppKit

struct AppLibraryView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("savedApps") var savedAppsData: Data = Data()
    @AppStorage("appTheme") var appTheme: String = "dark"
    @State private var apps: [AppItem] = []
    @State private var showAddSheet = false
    @State private var editingApp: AppItem? = nil
    @State private var installedApps: [InstalledApp] = []
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.92) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    let columns = [GridItem(.adaptive(minimum: 140))]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Uygulama Kütüphanesi")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(textColor)
                        Text("Proxy üzerinden çalıştırılacak uygulamalar")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { 
                        loadInstalledApps()
                        showAddSheet = true 
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Uygulama Ekle")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Apps Grid
                LazyVGrid(columns: columns, spacing: 15) {
                    // Default Discord
                    AppCard(
                        name: "Discord",
                        path: "/Applications/Discord.app",
                        isDefault: true,
                        cardBg: cardBg,
                        textColor: textColor,
                        onLaunch: { service.launchDiscord() },
                        onEdit: { 
                            // Create a temporary AppItem for editing the default
                            editingApp = AppItem(name: "Discord", path: "/Applications/Discord.app")
                        },
                        onDelete: {
                            // In this simple version, we'll just hide it or allow removal from UI
                            // For a more robust solution, we'd need to track 'removedDefaults'
                        }
                    )
                    
                    // User Apps
                    ForEach(apps) { app in
                        AppCard(
                            name: app.name,
                            path: app.path,
                            isDefault: false,
                            cardBg: cardBg,
                            textColor: textColor,
                            onLaunch: { launchApp(app) },
                            onEdit: { editingApp = app },
                            onDelete: { deleteApp(app) }
                        )
                    }
                }
            }
            .padding(30)
        }
        .background(bgColor)
        .onAppear {
            loadApps()
            loadInstalledApps()
        }
        .sheet(isPresented: $showAddSheet) {
            AddAppSheet(installedApps: installedApps, isLightTheme: appTheme == "light", onAdd: { newApp in
                apps.append(newApp)
                saveApps()
            })
        }
        .sheet(item: $editingApp) { app in
            EditAppSheet(app: app, isLightTheme: appTheme == "light", onSave: { updated in
                if let idx = apps.firstIndex(where: { $0.id == updated.id }) {
                    apps[idx] = updated
                    saveApps()
                }
            })
        }
    }
    
    func loadApps() {
        if let decoded = try? JSONDecoder().decode([AppItem].self, from: savedAppsData) {
            apps = decoded
        }
    }
    
    func saveApps() {
        if let encoded = try? JSONEncoder().encode(apps) {
            savedAppsData = encoded
        }
    }
    
    func deleteApp(_ app: AppItem) {
        withAnimation {
            apps.removeAll { $0.id == app.id }
            saveApps()
        }
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
    
    func loadInstalledApps() {
        let paths = ["/Applications", NSHomeDirectory() + "/Applications"]
        var found: [InstalledApp] = []
        
        for basePath in paths {
            if let items = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                for item in items where item.hasSuffix(".app") {
                    let fullPath = basePath + "/" + item
                    let name = item.replacingOccurrences(of: ".app", with: "")
                    found.append(InstalledApp(name: name, path: fullPath))
                }
            }
        }
        installedApps = found.sorted { $0.name < $1.name }
    }
}

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let path: String
}

// MARK: - App Card with Hover Actions
struct AppCard: View {
    let name: String
    let path: String
    let isDefault: Bool
    let cardBg: Color
    let textColor: Color
    let onLaunch: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 12) {
                // App Icon
                AppIconView(path: path, fallbackIcon: "app.fill")
                    .frame(width: 56, height: 56)
                
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .frame(width: 140, height: 130)
            .background(cardBg)
            .cornerRadius(12)
            .overlay(
                // Hover overlay with transparent glass effect
                Group {
                    if isHovered {
                        ZStack {
                            // Semi-transparent blur background
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.85))
                            
                            // Action buttons
                            HStack(spacing: 12) {
                                // Launch button
                                Button(action: onLaunch) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 22))
                                        Text("Aç")
                                            .font(.system(size: 8, weight: .medium))
                                    }
                                    .foregroundColor(.green)
                                    .frame(width: 36)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Edit button
                                Button(action: onEdit) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 22))
                                        Text("Düzen")
                                            .font(.system(size: 8, weight: .medium))
                                    }
                                    .foregroundColor(.blue)
                                    .frame(width: 36)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Delete button
                                Button(action: { showDeleteConfirm = true }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 22))
                                        Text("Sil")
                                            .font(.system(size: 8, weight: .medium))
                                    }
                                    .foregroundColor(.red)
                                    .frame(width: 36)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: isHovered)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Uygulamayı Sil", isPresented: $showDeleteConfirm) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) { onDelete() }
        } message: {
            Text("\(name) uygulamasını listeden kaldırmak istediğinize emin misiniz?")
        }
    }
}

// MARK: - Add App Sheet (Fixed for Light Theme)
struct AddAppSheet: View {
    let installedApps: [InstalledApp]
    let isLightTheme: Bool
    let onAdd: (AppItem) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedApp: InstalledApp? = nil
    
    var textColor: Color { isLightTheme ? .black : .white }
    var bgColor: Color { isLightTheme ? Color(white: 0.95) : Color(white: 0.15) }
    var cardBg: Color { isLightTheme ? Color(white: 0.90) : Color(white: 0.12) }
    
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty { return installedApps }
        return installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Uygulama Ekle")
                    .font(.headline)
                    .foregroundColor(textColor)
                Spacer()
                Button("İptal") { dismiss() }
                    .foregroundColor(.blue)
            }
            .padding()
            .background(.thinMaterial)
            
            Divider()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Uygulama ara...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(textColor)
            }
            .padding(10)
            .background(.regularMaterial)
            .cornerRadius(8)
            .padding()
            
            // Apps List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        HStack(spacing: 12) {
                            AppIconView(path: app.path, fallbackIcon: "app.fill")
                                .frame(width: 32, height: 32)
                            
                            Text(app.name)
                                .foregroundColor(textColor)
                            
                            Spacer()
                            
                            if selectedApp?.id == app.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(selectedApp?.id == app.id ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedApp = app
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 300)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Actions
            HStack {
                Button("Dosyadan Seç...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.application]
                    if panel.runModal() == .OK, let url = panel.url {
                        let name = url.deletingPathExtension().lastPathComponent
                        let newApp = AppItem(name: name, path: url.path)
                        onAdd(newApp)
                        dismiss()
                    }
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Button("Ekle") {
                    if let app = selectedApp {
                        let newApp = AppItem(name: app.name, path: app.path)
                        onAdd(newApp)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedApp == nil)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(width: 400, height: 520)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Edit App Sheet
struct EditAppSheet: View {
    let app: AppItem
    let isLightTheme: Bool
    let onSave: (AppItem) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var customArgs: String = ""
    
    var textColor: Color { isLightTheme ? .black : .white }
    var bgColor: Color { isLightTheme ? Color(white: 0.95) : Color(white: 0.18) }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Uygulamayı Düzenle")
                .font(.headline)
                .foregroundColor(textColor)
            
            HStack(spacing: 15) {
                AppIconView(path: app.path, fallbackIcon: "app.fill")
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading) {
                    TextField("Uygulama Adı", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Text(app.path)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Özel Argümanlar")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                TextField("--proxy-server=socks5://127.0.0.1:1080", text: $customArgs)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Button("İptal") { dismiss() }
                    .foregroundColor(.blue)
                Spacer()
                Button("Kaydet") {
                    var updated = app
                    updated.name = name
                    updated.customArgs = customArgs
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(bgColor)
        .onAppear {
            name = app.name
            customArgs = app.customArgs
        }
    }
}
