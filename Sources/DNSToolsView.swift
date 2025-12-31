import SwiftUI

struct DNSToolsView: View {
    @ObservedObject var service: ServiceManager
    @AppStorage("appTheme") var appTheme: String = "dark"
    @State private var isTesting = false
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.90) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.08) }
    
    let dnsList: [(ip: String, name: String, desc: String)] = [
        ("1.1.1.1", "Cloudflare", "Hızlı ve gizlilik odaklı"),
        ("8.8.8.8", "Google", "Güvenilir ve yaygın"),
        ("208.67.222.222", "OpenDNS", "Cisco tarafından"),
        ("9.9.9.9", "Quad9", "Zararlı site koruması"),
        ("194.242.2.2", "Mullvad", "Log tutmaz")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("DNS Araçları")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(textColor)
                
                // Test Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hız Testi")
                            .font(.headline)
                            .foregroundColor(textColor)
                        Text("Tüm DNS sunucularına ping")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: runTest) {
                        HStack(spacing: 8) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "bolt.fill")
                            }
                            Text(isTesting ? "Test Ediliyor..." : "Testi Başlat")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isTesting)
                }
                .padding(20)
                .background(cardBg)
                .cornerRadius(12)
                
                // Results
                VStack(alignment: .leading, spacing: 12) {
                    Text("DNS Sunucuları")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    ForEach(dnsList, id: \.ip) { dns in
                        DNSRow(
                            name: dns.name,
                            ip: dns.ip,
                            desc: dns.desc,
                            result: service.pingResults[dns.ip],
                            cardBg: cardBg,
                            textColor: textColor
                        )
                    }
                }
            }
            .padding(30)
        }
        .background(bgColor)
    }
    
    func runTest() {
        isTesting = true
        service.pingResults = [:]
        for dns in dnsList { service.pingDNS(host: dns.ip) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { isTesting = false }
    }
}

struct DNSRow: View {
    let name: String
    let ip: String
    let desc: String
    let result: String?
    let cardBg: Color
    let textColor: Color
    
    var latencyColor: Color {
        guard let result = result else { return .gray }
        if result.contains("Err") || result.contains("Fail") { return .red }
        if let ms = Double(result.replacingOccurrences(of: " ms", with: "")) {
            if ms < 30 { return .green }
            if ms < 100 { return .yellow }
        }
        return .red
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(textColor)
                HStack(spacing: 8) {
                    Text(ip).font(.caption).foregroundColor(.blue)
                    Text("•").foregroundColor(.gray)
                    Text(desc).font(.caption).foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if let result = result {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .bold()
                    .foregroundColor(latencyColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(latencyColor.opacity(0.15))
                    .cornerRadius(8)
            } else {
                Text("--")
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(cardBg)
        .cornerRadius(12)
    }
}
