import Foundation

enum ProxyEngineType: String, Codable, CaseIterable {
    case byedpi = "ByeDPI"
    case spoofdpi = "SpoofDPI"
    
    var displayName: String { rawValue }
    
    var dependency: Dependency {
        switch self {
        case .byedpi: return .ciadpi
        case .spoofdpi: return .spoofdpi
        }
    }
}

protocol ProxyEngine {
    var type: ProxyEngineType { get }
    var isRunning: Bool { get }
    func start(port: String, preset: BypassPreset?) async throws
    func stop() async
}
