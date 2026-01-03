import SwiftUI

struct LogView: View {
    @ObservedObject var service: ServiceManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("logs.title")) // You might need to add this key or use literal
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                
                Button(action: {
                    service.logs = ""
                }) {
                    Label(L("logs.clear"), systemImage: "trash")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Logs Area
            ScrollViewReader { proxy in
                ScrollView {
                    Text(service.logs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                        .id("logBottom")
                }
                .onChange(of: service.logs) { _ in
                    // Auto-scroll to bottom
                    withAnimation {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .navigationTitle("") // Hide title
    }
    
    func L(_ key: String) -> String {
        return NSLocalizedString(key, comment: "") == key ? (key == "logs.title" ? "Uygulama Kayıtları" : "Temizle") : NSLocalizedString(key, comment: "")
    }
}
