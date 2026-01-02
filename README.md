# BayMacDPI

<div align="center">

![BayMacDPI Logo](Screenshots/logo.png)

**macOS için DPI Bypass Aracı** | **DPI Bypass Tool for macOS**

[![macOS](https://img.shields.io/badge/macOS-15.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

[English](#english) | [Türkçe](#türkçe)

</div>

---

## English

### What is BayMacDPI?

BayMacDPI is a native macOS application that helps bypass Deep Packet Inspection (DPI) restrictions. It provides a beautiful, modern interface to manage the [ByeDPI](https://github.com/hufrea/byedpi) proxy service on your Mac.

### Features

| Feature | Description |
|---------|-------------|
| 🚀 **One-Click Start** | Start/stop the DPI bypass service instantly |
| 📱 **App Launcher** | Launch apps (Discord, etc.) through the proxy |
| ⚙️ **Custom Profiles** | Standard, Gaming, Streaming, Privacy presets |
| 🌐 **DNS Tools** | Test DNS servers with latency checks |
| 🎨 **Modern UI** | Native SwiftUI with glass effects |
| 🔄 **Auto-Install** | Binary auto-downloads on first run |

### Screenshots

<div align="center">

| Dashboard | App Library | Settings |
|:---------:|:-----------:|:--------:|
| ![Dashboard](Screenshots/dashboard.png) | ![Apps](Screenshots/apps.png) | ![Settings](Screenshots/settings.png) |

</div>

### Installation

#### Option 1: Download Release
1. Download `BayMacDPI.dmg` from [Releases](../../releases)
2. Open the DMG and drag to Applications
3. Launch BayMacDPI

#### Option 2: Build from Source
```bash
git clone https://github.com/grxtor/BayMacDPI.git
cd BayMacDPI
./build_app.sh
open "Build/BayMacDPI.app"
```

### Requirements
- macOS 15.0 (Sequoia) or later
- Apple Silicon (M1/M2/M3) or Intel Mac

---

## Türkçe

### BayMacDPI Nedir?

BayMacDPI, Deep Packet Inspection (DPI) kısıtlamalarını aşmanıza yardımcı olan native bir macOS uygulamasıdır. Mac'inizde [ByeDPI](https://github.com/hufrea/byedpi) proxy servisini yönetmek için güzel ve modern bir arayüz sunar.

### Özellikler

| Özellik | Açıklama |
|---------|----------|
| 🚀 **Tek Tıkla Başlat** | DPI bypass servisini anında başlat/durdur |
| 📱 **Uygulama Başlatıcı** | Uygulamaları (Discord, vb.) proxy üzerinden başlat |
| ⚙️ **Özel Profiller** | Standart, Oyun, Streaming, Gizlilik profilleri |
| 🌐 **DNS Araçları** | DNS sunucularını gecikme testleriyle kontrol et |
| 🎨 **Modern Arayüz** | Glass efektli native SwiftUI tasarım |
| 🔄 **Otomatik Kurulum** | İlk çalıştırmada binary otomatik indirilir |

### Kurulum

#### Seçenek 1: Release İndir
1. [Releases](../../releases) sayfasından `BayMacDPI.dmg` indir
2. DMG'yi aç ve Applications'a sürükle
3. BayMacDPI'ı başlat

#### Seçenek 2: Kaynak Koddan Derle
```bash
git clone https://github.com/grxtor/BayMacDPI.git
cd BayMacDPI
./build_app.sh
open "Build/BayMacDPI.app"
```

---

## How It Works / Nasıl Çalışır?

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│   Your App      │ ──► │  BayMacDPI   │ ──► │  Internet   │
│ (Discord, etc.) │     │ SOCKS5 Proxy │     │  (No DPI)   │
└─────────────────┘     └──────────────┘     └─────────────┘
```

1. **BayMacDPI** starts a local SOCKS5 proxy (default: `127.0.0.1:1080`)
2. The proxy uses DPI bypass techniques (packet splitting, TTL manipulation)
3. Apps connect through this proxy to bypass restrictions

---

## License / Lisans

MIT License - See [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ for a free internet**

</div>
