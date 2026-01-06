import SwiftUI

struct SetupWizardView: View {
    @StateObject private var dependencyManager = DependencyManager.shared
    @AppStorage("setupCompleted") var setupCompleted: Bool = false
    @AppStorage("appTheme") var appTheme: String = "dark"
    
    @State private var currentStep: SetupStep = .welcome
    @State private var isInstalling = false
    @State private var installError: String?
    @State private var installCloudflared = true
    
    var textColor: Color { appTheme == "light" ? .black : .white }
    var cardBg: Color { appTheme == "light" ? Color(white: 0.92) : Color(white: 0.12) }
    var bgColor: Color { appTheme == "light" ? Color(white: 0.95) : Color(white: 0.06) }
    
    enum SetupStep: Int, CaseIterable {
        case welcome = 0
        case dependencies = 1
        case installing = 2
        case complete = 3
    }
    
    var body: some View {
        ZStack {
            bgColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Progress Indicator
                HStack(spacing: 8) {
                    ForEach(SetupStep.allCases, id: \.rawValue) { step in
                        Capsule()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)
                
                Spacer()
                
                // Content
                switch currentStep {
                case .welcome:
                    welcomeView
                case .dependencies:
                    dependenciesView
                case .installing:
                    installingView
                case .complete:
                    completeView
                }
                
                Spacer()
                
                // Navigation Buttons
                HStack {
                    if currentStep != .welcome && currentStep != .installing {
                        Button(action: previousStep) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Geri")
                            }
                            .foregroundColor(.gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                    
                    if currentStep != .installing {
                        Button(action: nextStep) {
                            HStack {
                                Text(nextButtonText)
                                if currentStep != .complete {
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(40)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    // MARK: - Views
    
    var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
            
            Text("ByeMacDPI'ya Hoş Geldiniz")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(textColor)
            
            Text("DPI kısıtlamalarını aşmak için birkaç bileşen kurulacak.\nBu işlem internet bağlantısı gerektirir.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "bolt.shield", title: "DPI Bypass", desc: "Paket bölme ve TTL manipülasyonu")
                FeatureRow(icon: "lock.shield", title: "Şifreli DNS", desc: "DNS-over-HTTPS ile gizli sorgular")
                FeatureRow(icon: "app.badge.checkmark", title: "Uygulama Başlatıcı", desc: "Discord ve diğer uygulamalar için hızlı erişim")
            }
            .padding(.top, 20)
        }
    }
    
    var dependenciesView: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
            
            Text("Bileşenleri Kur")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textColor)
            
            Text("Aşağıdaki bileşenler GitHub'dan indirilecek:")
                .font(.body)
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                ForEach(Dependency.allCases) { dep in
                    DependencyRow(
                        dependency: dep,
                        isSelected: dep == .ciadpi ? true : installCloudflared,
                        isRequired: dep.isRequired,
                        onToggle: {
                            if dep == .cloudflared {
                                installCloudflared.toggle()
                            }
                        },
                        cardBg: cardBg,
                        textColor: textColor
                    )
                }
            }
            .padding(.horizontal, 60)
            
            if let error = installError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            Text("Bu bileşenler ~/Library/Application Support/ByeMacDPI/bin dizinine kurulacak.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }
    
    var installingView: some View {
        VStack(spacing: 24) {
            if let current = dependencyManager.currentDownload {
                Image(systemName: current.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
                
                Text("\(current.displayName) Kuruluyor...")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textColor)
            } else {
                ProgressView()
                    .scaleEffect(2)
                
                Text("Hazırlanıyor...")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textColor)
            }
            
            ProgressView(value: dependencyManager.downloadProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 300)
            
            Text("\(Int(dependencyManager.downloadProgress * 100))%")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.gray)
            
            if let error = installError {
                VStack(spacing: 8) {
                    Text("⚠️ Hata Oluştu")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    
                    Button("Tekrar Dene") {
                        installError = nil
                        startInstallation()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    var completeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Kurulum Tamamlandı!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(textColor)
            
            Text("ByeMacDPI kullanıma hazır.\nArtık DPI kısıtlamalarını aşabilirsiniz!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Dependency.allCases) { dep in
                    HStack(spacing: 12) {
                        Image(systemName: dependencyManager.isInstalled(dep) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(dependencyManager.isInstalled(dep) ? .green : .gray)
                        
                        Text(dep.displayName)
                            .foregroundColor(textColor)
                        
                        if let version = dependencyManager.getInstalledVersion(dep) {
                            Text(version)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Navigation
    
    var nextButtonText: String {
        switch currentStep {
        case .welcome: return "Başla"
        case .dependencies: return "Kur"
        case .installing: return ""
        case .complete: return "Başlat"
        }
    }
    
    func nextStep() {
        withAnimation(.spring(response: 0.4)) {
            switch currentStep {
            case .welcome:
                currentStep = .dependencies
            case .dependencies:
                currentStep = .installing
                startInstallation()
            case .installing:
                break
            case .complete:
                setupCompleted = true
            }
        }
    }
    
    func previousStep() {
        withAnimation(.spring(response: 0.4)) {
            switch currentStep {
            case .welcome:
                break
            case .dependencies:
                currentStep = .welcome
            case .installing:
                break
            case .complete:
                currentStep = .dependencies
            }
        }
    }
    
    func startInstallation() {
        isInstalling = true
        installError = nil
        
        Task {
            do {
                // Install ciadpi (required)
                try await dependencyManager.install(.ciadpi)
                
                // Install cloudflared (optional)
                if installCloudflared {
                    try await dependencyManager.install(.cloudflared)
                }
                
                await MainActor.run {
                    isInstalling = false
                    withAnimation(.spring(response: 0.4)) {
                        currentStep = .complete
                    }
                }
            } catch {
                await MainActor.run {
                    isInstalling = false
                    installError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct DependencyRow: View {
    let dependency: Dependency
    let isSelected: Bool
    let isRequired: Bool
    let onToggle: () -> Void
    let cardBg: Color
    let textColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: dependency.icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(dependency.displayName)
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    if isRequired {
                        Text("Zorunlu")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                Text(dependency.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isRequired {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Toggle("", isOn: .constant(isSelected))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                    .onTapGesture { onToggle() }
            }
        }
        .padding(16)
        .background(cardBg)
        .cornerRadius(12)
        .opacity(isSelected ? 1 : 0.6)
    }
}

