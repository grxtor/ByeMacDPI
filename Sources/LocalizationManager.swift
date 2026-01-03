import SwiftUI

class LocalizationManager: ObservableObject {
    @AppStorage("appLanguage") var appLanguage: String = "system" // system, tr, en
    @Published var strings: [String: String] = [:]
    
    static let shared = LocalizationManager()
    
    init() {
        loadLanguage()
    }
    
    func loadLanguage() {
        let langCodeToLoad: String
        if appLanguage == "system" {
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            langCodeToLoad = (systemLang == "tr") ? "tr" : "en"
        } else {
            langCodeToLoad = appLanguage
        }
        
        switch langCodeToLoad {
        case "tr":
            strings = TurkishStrings
        case "en":
            strings = EnglishStrings
        default:
            strings = EnglishStrings
        }
    }
    
    func setLanguage(_ code: String) {
        appLanguage = code
        loadLanguage()
    }
    
    func localized(_ key: String) -> String {
        return strings[key] ?? key
    }
}

// Global helper
func L(_ key: String) -> String {
    return LocalizationManager.shared.localized(key)
}

// MARK: - Language Data
// In a real app, these would be in separate JSON or files
private let TurkishStrings: [String: String] = [
    // Dashboard
    "dashboard.title": "Panel",
    "dashboard.active": "BayMacDPI Aktif",
    "dashboard.inactive": "BayMacDPI Kapalı",
    "dashboard.start_hint": "Servisi başlatmak için butona tıklayın",
    "dashboard.config.protocol": "Protokol",
    "dashboard.config.port": "Port",
    "dashboard.config.split": "Split",
    "dashboard.config.system_proxy": "Sistem Proxy",
    "dashboard.presets": "Profiller",
    "dashboard.apps": "Uygulamalar",
    "preset.standard": "Standart",
    "preset.game": "Oyun",
    "preset.streaming": "Medyalar",
    "preset.privacy": "Gizlilik",
    
    // Sidebar
    "sidebar.general": "Genel",
    "sidebar.config": "Yapılandırma",
    "sidebar.system": "Sistem",
    
    // Settings
    "settings.title": "Ayarlar",
    "settings.theme": "Tema",
    "settings.theme.dark": "Karanlık",
    "settings.theme.light": "Aydınlık",
    "settings.theme.transparent": "Şeffaf",
    "settings.startup": "Başlangıç",
    "settings.startup.login": "Giriş Sırasında Başlat",
    "settings.startup.login_desc": "macOS açıldığında BayMacDPI servisini başlat",
    "settings.startup.auto_connect": "Otomatik Bağlan",
    "settings.startup.auto_connect_desc": "Uygulama açıldığında servisi başlat",
    "settings.customization": "Kişiselleştirme",
    "settings.customization.binary_path": "DPI Binary Yolu",
    "settings.customization.change": "Değiştir",
    "settings.customization.open_folder": "Klasörü Aç",
    "settings.language": "Dil",
    "settings.language.system": "Sistem",
    "settings.language.tr": "Türkçe",
    "settings.language.en": "English",
    "settings.about": "Hakkında",
    "settings.about.version": "Sürüm",
    "settings.about.desc": "macOS için DPI Bypass aracı",
    "settings.about.license": "GPL v3 Lisansı ile açık kaynak",
    "settings.about.reset": "Kurulumu Tekrarla",
    
    // App Library
    "library.title": "Uygulama Kütüphanesi",
    "library.subtitle": "Proxy üzerinden çalıştırılacak uygulamalar",
    "library.add": "Uygulama Ekle",
    "library.edit": "Düzenle",
    "library.delete": "Sil",
    "library.delete_confirm_title": "Uygulamayı Sil",
    "library.delete_confirm_msg": "Bu uygulamayı kütüphaneden silmek istediğine emin misin?",
    "library.cancel": "İptal",
    
    // Protocols
    "protocols.title": "Protokol Ayarları",
    "protocols.proxy_type": "Proxy Türü",
    "protocols.connection": "Bağlantı",
    "protocols.timeout": "Zaman Aşımı (sn)",
    "protocols.max_conn": "Maks. Bağlantı",
    "protocols.dpi_bypass": "DPI Bypass",
    "protocols.split_mode": "Split Modu",
    "protocols.ttl": "TTL Değeri",
    "protocols.custom_args": "Özel Argümanlar",
    "protocols.dns": "DNS over HTTPS",
    
    // Menu
    "menu.start": "Başlat",
    "menu.stop": "Durdur",
    "menu.show": "Uygulamayı Göster",
    "menu.quit": "Çıkış",
    
    // Onboarding
    "onboarding.welcome": "Hoş Geldiniz",
    "onboarding.step1": "Temel Kurulum",
    "onboarding.step2": "DNS Testi",
    "onboarding.step3": "Konfigürasyon",
    "onboarding.finish": "Başla",
    "onboarding.checking": "Kontrol ediliyor...",
    "onboarding.ready": "Hazır",
    
    // Common
    "common.error": "Hata",
    "common.error": "Hata",
    "common.success": "Başarılı",
    "common.save": "Kaydet",
    "common.add": "Ekle",
    
    // Additional Library Keys
    "library.add_title": "Uygulama Ekle",
    "library.search_placeholder": "Uygulama ara...",
    "library.select_file": "Dosyadan Seç...",
    "library.edit_title": "Uygulamayı Düzenle",
    "library.app_name": "Uygulama Adı"
]

private let EnglishStrings: [String: String] = [
    // Dashboard
    "dashboard.title": "Dashboard",
    "dashboard.active": "BayMacDPI Active",
    "dashboard.inactive": "BayMacDPI Inactive",
    "dashboard.start_hint": "Click button to start service",
    "dashboard.config.protocol": "Protocol",
    "dashboard.config.port": "Port",
    "dashboard.config.split": "Split",
    "dashboard.config.system_proxy": "System Proxy",
    "dashboard.presets": "Presets",
    "dashboard.apps": "Apps",
    "preset.standard": "Standard",
    "preset.game": "Gaming",
    "preset.streaming": "Streaming",
    "preset.privacy": "Privacy",
    
    // Sidebar
    "sidebar.general": "General",
    "sidebar.config": "Configuration",
    "sidebar.system": "System",
    
    // Settings
    "settings.title": "Settings",
    "settings.theme": "Theme",
    "settings.theme.dark": "Dark",
    "settings.theme.light": "Light",
    "settings.theme.transparent": "Transparent",
    "settings.startup": "Startup",
    "settings.startup.login": "Launch at Login",
    "settings.startup.login_desc": "Start BayMacDPI when macOS starts",
    "settings.startup.auto_connect": "Auto Connect",
    "settings.startup.auto_connect_desc": "Start service when app opens",
    "settings.customization": "Customization",
    "settings.customization.binary_path": "DPI Binary Path",
    "settings.customization.change": "Change",
    "settings.customization.open_folder": "Open Folder",
    "settings.language": "Language",
    "settings.language.system": "System",
    "settings.language.tr": "Türkçe",
    "settings.language.en": "English",
    "settings.about": "About",
    "settings.about.version": "Version",
    "settings.about.desc": "DPI Bypass tool for macOS",
    "settings.about.license": "Open source under GPL v3 License",
    "settings.about.reset": "Reset Setup",
    
    // App Library
    "library.title": "App Library",
    "library.subtitle": "Applications to tunnel through proxy",
    "library.add": "Add App",
    "library.edit": "Edit",
    "library.delete": "Delete",
    "library.delete_confirm_title": "Delete App",
    "library.delete_confirm_msg": "Are you sure you want to delete this app?",
    "library.cancel": "Cancel",
    
    // Protocols
    "protocols.title": "Protocol Settings",
    "protocols.proxy_type": "Proxy Type",
    "protocols.connection": "Connection",
    "protocols.timeout": "Timeout (s)",
    "protocols.max_conn": "Max Conn",
    "protocols.dpi_bypass": "DPI Bypass",
    "protocols.split_mode": "Split Mode",
    "protocols.ttl": "TTL Value",
    "protocols.custom_args": "Custom Args",
    "protocols.dns": "DNS over HTTPS",
    
    // Menu
    "menu.start": "Start",
    "menu.stop": "Stop",
    "menu.show": "Show App",
    "menu.quit": "Quit",
    
    // Onboarding
    "onboarding.welcome": "Welcome",
    "onboarding.step1": "Basic Setup",
    "onboarding.step2": "DNS Test",
    "onboarding.step3": "Configuration",
    "onboarding.finish": "Start",
    "onboarding.checking": "Checking...",
    "onboarding.ready": "Ready",
    
    // Common
    "common.error": "Error",
    "common.error": "Error",
    "common.success": "Success",
    "common.save": "Save",
    "common.add": "Add",
    
    // Additional Library Keys
    "library.add_title": "Add Application",
    "library.search_placeholder": "Search apps...",
    "library.select_file": "Select from File...",
    "library.edit_title": "Edit Application",
    "library.app_name": "App Name"
]
