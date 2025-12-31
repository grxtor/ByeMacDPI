import SwiftUI

struct AppIconView: View {
    let path: String
    let fallbackIcon: String
    
    @State private var iconImage: NSImage?
    
    var body: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallbackIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            if !path.isEmpty {
                iconImage = NSWorkspace.shared.icon(forFile: path)
            }
        }
    }
}

struct AppGridItem: View {
    let name: String
    let path: String
    let fallbackIcon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                // Icon Container
                ZStack {
                    if path.isEmpty {
                         // Fallback style for like generic or internal actions if path isn't real
                         Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 70, height: 70)
                         Image(systemName: fallbackIcon)
                             .resizable()
                             .aspectRatio(contentMode: .fit)
                             .frame(width: 35, height: 35)
                             .foregroundColor(color)
                    } else {
                        // Real App Icon
                        AppIconView(path: path, fallbackIcon: fallbackIcon)
                            .frame(width: 64, height: 64)
                            .shadow(radius: 5)
                    }
                }
                
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 140, height: 140) // Square and Large
            .background(Color(white: 0.15).opacity(0.6))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
