import Foundation

struct AppItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var iconPath: String? // Path to an .icns or just use system icon based on path via NSWorkspace
    var customArgs: String = "--args --proxy-server=socks5://127.0.0.1:1080 --ignore-certificate-errors"
}
