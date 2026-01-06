import Foundation
import Combine
import AppKit

// MARK: - Dependency Definition
enum Dependency: String, CaseIterable, Identifiable {
    case ciadpi = "ciadpi"
    case cloudflared = "cloudflared"
    case spoofdpi = "spoof-dpi"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .ciadpi: return "ByeDPI (ciadpi)"
        case .cloudflared: return "Cloudflare DNS Proxy"
        case .spoofdpi: return "SpoofDPI"
        }
    }
    
    var description: String {
        switch self {
        case .ciadpi: return "DPI bypass için gerekli ana bileşen"
        case .cloudflared: return "DNS-over-HTTPS için şifreli DNS proxy"
        case .spoofdpi: return "Alternatif modern DPI bypass aracı"
        }
    }
    
    var icon: String {
        switch self {
        case .ciadpi: return "shield.checkered"
        case .cloudflared: return "network.badge.shield.half.filled"
        case .spoofdpi: return "bolt.shield"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .ciadpi: return true
        case .cloudflared: return false
        case .spoofdpi: return false
        }
    }
    
    var githubRepo: String {
        switch self {
        case .ciadpi: return "hufrea/byedpi"
        case .cloudflared: return "cloudflare/cloudflared"
        case .spoofdpi: return "xvzc/SpoofDPI"
        }
    }
    
    var assetNamePattern: String {
        let arch = ProcessInfo.processInfo.machineArchitecture
        let isArm = arch.lowercased().contains("arm") || arch.lowercased().contains("aarch64")
        
        switch self {
        case .ciadpi:
            // hufrea/byedpi uses aarch64 & x86_64
            return isArm ? "aarch64.tar.gz" : "x86_64.tar.gz"
        case .cloudflared:
            return isArm ? "cloudflared-darwin-arm64.tgz" : "cloudflared-darwin-amd64.tgz"
        case .spoofdpi:
            // xvzc/SpoofDPI uses darwin_arm64 and darwin_x86_64
            return isArm ? "darwin_arm64.tar.gz" : "darwin_x86_64.tar.gz"
        }
    }
    
    var binaryName: String {
        switch self {
        case .spoofdpi: return "spoofdpi"
        case .ciadpi: return "ciadpi"
        default: return rawValue
        }
    }
}

// MARK: - Version Info
struct VersionInfo: Codable {
    let version: String
    let downloadedAt: Date
    let assetName: String
}

// MARK: - Dependency Manager
class DependencyManager: ObservableObject {
    static let shared = DependencyManager()
    
    @Published var installedDependencies: Set<Dependency> = []
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var currentDownload: Dependency?
    @Published var errorMessage: String?
    @Published var availableUpdates: [Dependency: String] = [:]
    
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    private var installDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ByeMacDPI/bin")
    }
    
    private var versionsFile: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ByeMacDPI/versions.json")
    }
    
    init() {
        setupDirectories()
        checkInstalledDependencies()
    }
    
    private func setupDirectories() {
        try? fileManager.createDirectory(at: installDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    func isInstalled(_ dependency: Dependency) -> Bool {
        installedDependencies.contains(dependency)
    }
    
    func getPath(_ dependency: Dependency) -> String? {
        let path = installDirectory.appendingPathComponent(dependency.binaryName).path
        return fileManager.isExecutableFile(atPath: path) ? path : nil
    }
    
    func checkInstalledDependencies() {
        installedDependencies.removeAll()
        for dep in Dependency.allCases {
            if let path = getPath(dep), fileManager.fileExists(atPath: path) {
                installedDependencies.insert(dep)
            }
        }
    }
    
    func allRequiredInstalled() -> Bool {
        Dependency.allCases.filter(\.isRequired).allSatisfy { isInstalled($0) }
    }
    
    // MARK: - Download & Install
    
    func install(_ dependency: Dependency) async throws {
        await MainActor.run {
            isDownloading = true
            currentDownload = dependency
            downloadProgress = 0
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isDownloading = false
                currentDownload = nil
            }
        }
        
        // 1. Get latest release info from GitHub
        let releaseURL = URL(string: "https://api.github.com/repos/\(dependency.githubRepo)/releases/latest")!
        
        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DependencyError.networkError("GitHub API'ye erişilemedi")
        }
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        // 2. Find the correct asset
        guard let asset = release.assets.first(where: { $0.name.contains(dependency.assetNamePattern) || $0.name == dependency.assetNamePattern }) else {
            throw DependencyError.assetNotFound("Bu platform için binary bulunamadı: \(dependency.assetNamePattern)")
        }
        
        await MainActor.run { downloadProgress = 0.1 }
        
        // 3. Download the asset
        let downloadURL = URL(string: asset.browser_download_url)!
        let (downloadedURL, _) = try await URLSession.shared.download(from: downloadURL)
        
        await MainActor.run { downloadProgress = 0.6 }
        
        // 4. Extract and install
        let destinationPath = installDirectory.appendingPathComponent(dependency.binaryName)
        
        // Remove existing if any
        try? fileManager.removeItem(at: destinationPath)
        
        if asset.name.hasSuffix(".tgz") || asset.name.hasSuffix(".tar.gz") {
            // Extract tar.gz
            try await extractTarGz(downloadedURL, to: installDirectory, binaryName: dependency.binaryName)
        } else {
            // Direct binary - just move
            try fileManager.moveItem(at: downloadedURL, to: destinationPath)
        }
        
        await MainActor.run { downloadProgress = 0.8 }
        
        // 5. Make executable
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationPath.path)
        
        // 6. Remove quarantine
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-d", "com.apple.quarantine", destinationPath.path]
        xattr.standardOutput = FileHandle.nullDevice
        xattr.standardError = FileHandle.nullDevice
        try? xattr.run()
        xattr.waitUntilExit()
        
        // 7. Save version info
        try saveVersionInfo(dependency, version: release.tag_name, assetName: asset.name)
        
        await MainActor.run {
            downloadProgress = 1.0
            installedDependencies.insert(dependency)
        }
        
        print("[DependencyManager] ✅ Installed \(dependency.displayName) v\(release.tag_name)")
    }
    
    func uninstall(_ dependency: Dependency) throws {
        let path = installDirectory.appendingPathComponent(dependency.binaryName)
        try fileManager.removeItem(at: path)
        installedDependencies.remove(dependency)
        print("[DependencyManager] 🗑️ Uninstalled \(dependency.displayName)")
    }
    
    // MARK: - Update Check
    
    func checkForUpdates() async {
        for dep in installedDependencies {
            do {
                let releaseURL = URL(string: "https://api.github.com/repos/\(dep.githubRepo)/releases/latest")!
                var request = URLRequest(url: releaseURL)
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                
                if let current = getInstalledVersion(dep), current != release.tag_name {
                    await MainActor.run {
                        availableUpdates[dep] = release.tag_name
                    }
                }
            } catch {
                print("[DependencyManager] ⚠️ Update check failed for \(dep): \(error)")
            }
        }
    }
    
    func getInstalledVersion(_ dependency: Dependency) -> String? {
        guard let data = try? Data(contentsOf: versionsFile),
              let versions = try? JSONDecoder().decode([String: VersionInfo].self, from: data) else {
            return nil
        }
        return versions[dependency.rawValue]?.version
    }
    
    // MARK: - Private Helpers
    
    private func extractTarGz(_ tarPath: URL, to destination: URL, binaryName: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", tarPath.path, "-C", destination.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw DependencyError.extractionFailed("tar extraction failed")
        }
        
        // Find the binary in the destination (it might be nested)
        if let foundBinary = findBinary(name: binaryName, in: destination) {
            let finalTarget = destination.appendingPathComponent(binaryName)
            if foundBinary.path != finalTarget.path {
                try? fileManager.moveItem(at: foundBinary, to: finalTarget)
            }
        }
    }
    
    private func findBinary(name: String, in directory: URL) -> URL? {
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent.lowercased()
            let targetName = name.lowercased()
            
            // Match exact name, or name with architecture suffix (e.g. ciadpi-x86_64, spoof-dpi-darwin-arm64)
            if fileName == targetName || fileName.hasPrefix(targetName + "-") || fileName.hasPrefix(targetName + "_") {
                // Verify it's not a documentation or metadata file
                let ext = fileURL.pathExtension.lowercased()
                if ext == "" || ext == "exe" {
                    return fileURL
                }
            }
        }
        return nil
    }
    
    private func saveVersionInfo(_ dependency: Dependency, version: String, assetName: String) throws {
        var versions: [String: VersionInfo] = [:]
        if let data = try? Data(contentsOf: versionsFile) {
            versions = (try? JSONDecoder().decode([String: VersionInfo].self, from: data)) ?? [:]
        }
        
        versions[dependency.rawValue] = VersionInfo(
            version: version,
            downloadedAt: Date(),
            assetName: assetName
        )
        
        let data = try JSONEncoder().encode(versions)
        try data.write(to: versionsFile)
    }
    func wipe() throws {
        // Stop all services (caller should ensure this is called when services are stopped)
        try? fileManager.removeItem(at: installDirectory)
        try? fileManager.removeItem(at: versionsFile)
        
        // Clear User Defaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.synchronize()
        
        // Re-setup directories
        setupDirectories()
        installedDependencies.removeAll()
        availableUpdates.removeAll()
        
        print("[DependencyManager] 🧹 Application data wiped")
    }
}

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tag_name: String
    let name: String
    let assets: [GitHubAsset]
}

struct GitHubAsset: Codable {
    let name: String
    let browser_download_url: String
    let size: Int
}

// MARK: - Errors

enum DependencyError: LocalizedError {
    case networkError(String)
    case assetNotFound(String)
    case extractionFailed(String)
    case installFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Ağ Hatası: \(msg)"
        case .assetNotFound(let msg): return "Binary Bulunamadı: \(msg)"
        case .extractionFailed(let msg): return "Çıkarma Hatası: \(msg)"
        case .installFailed(let msg): return "Kurulum Hatası: \(msg)"
        }
    }
}

// MARK: - Machine Architecture Helper

extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
}
