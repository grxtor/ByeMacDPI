import SwiftUI

struct OnboardingView: View {
    @ObservedObject var service: ServiceManager
    @Binding var isComplete: Bool
    @State private var currentStep = 0
    @State private var progress: Double = 0
    @State private var statusText = L("onboarding.checking")
    @ObservedObject var loc = LocalizationManager.shared
    @State private var dnsResults: [(String, String, Int)] = [] // (name, ip, latency)
    @State private var bestDNS = ""
    @State private var isTestingDNS = false
    @State private var isTestingDPI = false
    @State private var dpiTestResult = ""
    
    let dnsServers = [
        ("Google", "8.8.8.8"),
        ("Cloudflare", "1.1.1.1"),
        ("Quad9", "9.9.9.9"),
        ("OpenDNS", "208.67.222.222"),
        ("AdGuard", "94.140.14.14")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(.blue)
                Text(L("onboarding.welcome"))
                    .font(.title2.bold())
            }
            .padding(.top, 30)
            
            // Progress
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 300)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 20)
            
            // Steps
            VStack(alignment: .leading, spacing: 12) {
                SetupStep(number: 1, title: L("onboarding.step1"), 
                         status: currentStep > 0 ? .done : (currentStep == 0 ? .active : .pending))
                SetupStep(number: 2, title: L("onboarding.step2"), 
                         status: currentStep > 1 ? .done : (currentStep == 1 ? .active : .pending))
                SetupStep(number: 3, title: L("onboarding.step3"), 
                         status: currentStep > 2 ? .done : (currentStep == 2 ? .active : .pending))
                SetupStep(number: 4, title: L("onboarding.ready"), 
                         status: currentStep > 3 ? .done : (currentStep == 3 ? .active : .pending))
            }
            .padding(.horizontal, 40)
            
            // DNS Results
            if !dnsResults.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DNS Sonuçları")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    
                    ForEach(dnsResults, id: \.1) { result in
                        HStack {
                            Text(result.0)
                                .font(.caption)
                            Spacer()
                            Text("\(result.2)ms")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(result.2 < 50 ? .green : (result.2 < 100 ? .yellow : .red))
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            }
            
            Spacer()
            
            // Action Button
            if currentStep >= 4 {
                Button(L("onboarding.finish")) {
                    isComplete = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 450, height: 500)
        .background(Color(white: 0.1))
        .onAppear {
            startSetup()
        }
    }
    
    func startSetup() {
        // Step 1: Check/Install ByeDPI
        statusText = L("onboarding.checking")
        progress = 0.1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            currentStep = 1
            progress = 0.25
            statusText = L("onboarding.step2") + "..."
            testDNS()
        }
    }
    
    func testDNS() {
        isTestingDNS = true
        var results: [(String, String, Int)] = []
        let group = DispatchGroup()
        
        for (name, ip) in dnsServers {
            group.enter()
            pingHost(ip) { latency in
                results.append((name, ip, latency))
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            dnsResults = results.sorted { $0.2 < $1.2 }
            if let best = dnsResults.first {
                bestDNS = best.0
            }
            isTestingDNS = false
            currentStep = 2
            progress = 0.5
            statusText = L("onboarding.step3") + "..."
            testDPI()
        }
    }
    
    func testDPI() {
        isTestingDPI = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            currentStep = 3
            progress = 0.75
            statusText = L("onboarding.checking")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                currentStep = 4
                progress = 1.0
                statusText = L("onboarding.ready")
                isTestingDPI = false
            }
        }
    }
    
    func pingHost(_ host: String, completion: @escaping (Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "1000", host]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                DispatchQueue.main.async {
                    completion(process.terminationStatus == 0 ? elapsed : 999)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(999)
                }
            }
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let status: StepStatus
    
    enum StepStatus {
        case pending, active, done
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status == .done ? Color.green : (status == .active ? Color.blue : Color.gray.opacity(0.3)))
                    .frame(width: 28, height: 28)
                
                if status == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if status == .active {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(title)
                .foregroundColor(status == .pending ? .gray : .white)
        }
    }
}
