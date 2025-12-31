import SwiftUI

struct ContentView: View {
    @StateObject private var service = ServiceManager()
    
    // Neon Colors
    let neonGreen = Color(red: 0.22, green: 1.0, blue: 0.08) // #39ff14
    let neonBlue = Color(red: 0.0, green: 0.95, blue: 1.0)   // #00f3ff
    let darkBg = Color(red: 0.04, green: 0.04, blue: 0.07)   // #0a0a12
    
    var body: some View {
        ZStack {
            // Background
            darkBg.edgesIgnoringSafeArea(.all)
            
            // Subtle Grid or Gradient
            RadialGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), darkBg]), center: .center, startRadius: 5, endRadius: 300)
            
            VStack(spacing: 30) {
                
                // HEADER
                HStack {
                    Circle()
                        .fill(service.isRunning ? neonGreen : Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: service.isRunning ? neonGreen : Color.red, radius: 5)
                    
                    Text("BYEDPI MANAGER")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.8))
                        .tracking(2)
                    
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 25)
                
                Spacer()
                
                // MAIN POWER BUTTON
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        service.toggleService()
                    }
                }) {
                    ZStack {
                        // Outer Glow Ring
                        Circle()
                            .stroke(service.isRunning ? neonGreen.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 2)
                            .frame(width: 140, height: 140)
                            .shadow(color: service.isRunning ? neonGreen : Color.clear, radius: 20)
                        
                        // Inner Button
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: service.isRunning ? [neonGreen.opacity(0.8), neonGreen.opacity(0.5)] : [Color.gray.opacity(0.3), Color.black]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "power")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .white, radius: service.isRunning ? 10 : 0)
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(service.statusMessage)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(service.isRunning ? neonGreen : Color.gray)
                    .shadow(color: service.isRunning ? neonGreen.opacity(0.6) : Color.clear, radius: 8)
                
                Spacer()
                
                // DISCORD LAUNCHER
                Button(action: {
                    service.launchDiscord()
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("LAUNCH VENCORD")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(darkBg)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(neonBlue)
                    .cornerRadius(8)
                    .shadow(color: neonBlue.opacity(0.7), radius: 10, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 30)
            }
        }
        .frame(width: 350, height: 500)
    }
}
