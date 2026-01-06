import SwiftUI

// MARK: - DNS Tab View
struct DNSTabView: View {
    @EnvironmentObject var dnsManager: DNSProxyManager
    @EnvironmentObject var dependencyManager: DependencyManager
    
    @AppStorage("appTheme") var appTheme: String = "dark"
    @AppStorage("selectedDNSProvider") var selectedDNSProvider: String = "cloudflare"
    @AppStorage("autoStartDNS") var autoStartDNS: Bool = false
    
    @State private var isTesting = false
    @State private var testResults: [String: String] = [:]
    @State private var showInstallAlert = false
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.92) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.06) }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("DNS Ayarları")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // DNS Proxy Status
                dnsStatusCard
                
                // Provider Selection
                if dependencyManager.isInstalled(.cloudflared) {
                    providerSelectionCard
                }
                
                // DNS Test
                dnsTestCard
                
                // Info Card
                infoCard
            }
            .padding(24)
        }
        .background(bgColor)
        .alert("cloudflared Gerekli", isPresented: $showInstallAlert) {
            Button("Kur") {
                Task {
                    try? await dependencyManager.install(.cloudflared)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("DNS-over-HTTPS kullanmak için cloudflared kurulmalı.")
        }
    }
    
    // MARK: - DNS Status Card
    var dnsStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "network.badge.shield.half.filled")
                    .foregroundColor(.blue)
                Text("DNS-over-HTTPS Proxy")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 16) {
                // Installation Status
                if !dependencyManager.isInstalled(.cloudflared) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("cloudflared kurulu değil")
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button("Kur") {
                            Task {
                                try? await dependencyManager.install(.cloudflared)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                } else {
                    // Status Row
                    HStack {
                        Text("Durum:")
                            .foregroundColor(textColor.opacity(0.7))
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(dnsManager.isRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            
                            Text(dnsManager.statusMessage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(dnsManager.isRunning ? .green : textColor.opacity(0.5))
                        }
                    }
                    
                    Divider()
                    
                    // Control Buttons
                    HStack(spacing: 12) {
                        Button(action: toggleDNSProxy) {
                            HStack {
                                if dnsManager.isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: dnsManager.isRunning ? "stop.fill" : "play.fill")
                                }
                                Text(dnsManager.isRunning ? "Durdur" : "Başlat")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(dnsManager.isRunning ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(dnsManager.isProcessing)
                        
                        Toggle(isOn: $autoStartDNS) {
                            Text("Otomatik Başlat")
                                .font(.caption)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    
                    // Local Proxy Info
                    if dnsManager.isRunning {
                        HStack {
                            Text("Yerel DNS:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("127.0.0.1:\(dnsManager.localPort)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("Provider: \(dnsManager.activeProvider.displayName)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(20)
            .background(cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Provider Selection
    var providerSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.purple)
                Text("DNS Sağlayıcı")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(DNSProvider.allCases) { provider in
                    ProviderCard(
                        provider: provider,
                        isSelected: selectedDNSProvider == provider.rawValue,
                        cardBg: cardBg,
                        textColor: textColor
                    ) {
                        withAnimation {
                            selectedDNSProvider = provider.rawValue
                            if dnsManager.isRunning {
                                Task {
                                    await dnsManager.stopDNSProxy()
                                    try? await dnsManager.startDNSProxy(provider: provider)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - DNS Test Card
    var dnsTestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Hız Testi")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: runDNSTest) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isTesting ? "Test Ediliyor..." : "Testi Başlat")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTesting)
            }
            
            // Test Results
            VStack(spacing: 8) {
                ForEach(DNSProvider.allCases) { provider in
                    HStack {
                        Image(systemName: provider.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textColor)
                            Text(provider.dohURL)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if let result = testResults[provider.rawValue] {
                            Text(result)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(resultColor(result))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(resultColor(result).opacity(0.15))
                                .cornerRadius(6)
                        } else {
                            Text("--")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(12)
                    .background(cardBg)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Info Card
    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("DNS-over-HTTPS Nedir?")
                    .font(.headline)
                    .foregroundColor(textColor)
            }
            
            Text("DNS-over-HTTPS (DoH), DNS sorgularınızı HTTPS protokolü üzerinden şifreleyerek gönderir. Bu sayede ISP'niz hangi sitelere gittiğinizi göremez ve DPI sistemleri DNS sorgularınızı engelleyemez.")
                .font(.caption)
                .foregroundColor(.gray)
                .lineSpacing(4)
            
            Text("⚠️ DNS proxy'yi etkinleştirdikten sonra sistem DNS'inizi 127.0.0.1 olarak ayarlamanız gerekebilir.")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.top, 4)
        }
        .padding(16)
        .background(cardBg)
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    func toggleDNSProxy() {
        Task {
            if dnsManager.isRunning {
                await dnsManager.stopDNSProxy()
            } else {
                guard let provider = DNSProvider(rawValue: selectedDNSProvider) else { return }
                try? await dnsManager.startDNSProxy(provider: provider)
            }
        }
    }
    
    func runDNSTest() {
        isTesting = true
        testResults = [:]
        
        Task {
            for provider in DNSProvider.allCases {
                let start = Date()
                
                // Simple HTTP request to measure DoH latency
                let url = URL(string: "\(provider.dohURL)?name=discord.com&type=A")!
                var request = URLRequest(url: url)
                request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 5
                
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        await MainActor.run {
                            testResults[provider.rawValue] = String(format: "%.0f ms", elapsed)
                        }
                    } else {
                        await MainActor.run {
                            testResults[provider.rawValue] = "Hata"
                        }
                    }
                } catch {
                    await MainActor.run {
                        testResults[provider.rawValue] = "Timeout"
                    }
                }
            }
            
            await MainActor.run {
                isTesting = false
            }
        }
    }
    
    func resultColor(_ result: String) -> Color {
        if result.contains("Hata") || result.contains("Timeout") {
            return .red
        }
        if let ms = Double(result.replacingOccurrences(of: " ms", with: "")) {
            if ms < 100 { return .green }
            if ms < 300 { return .yellow }
        }
        return .red
    }
}

// MARK: - Provider Card
struct ProviderCard: View {
    let provider: DNSProvider
    let isSelected: Bool
    let cardBg: Color
    let textColor: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: provider.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : textColor)
                    
                    Text(provider.description)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(isSelected ? Color.blue : (isHovered ? cardBg.opacity(1.2) : cardBg))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

