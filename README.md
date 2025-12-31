# ByeDPI Native

ByeDPI for macOS - SwiftUI tabanlı, modern ve hızlı bir ByeDPI (ciadpi) yönetim arayüzü.

## Özellikler

- **Modern Arayüz:** SwiftUI kullanılarak geliştirilmiş, macOS yerel deneyimi.
- **Hızlı Başlatma:** Discord (veya özel uygulamalar) için proxy argümanlarıyla tek tıkla başlatma.
- **Uygulama Kütüphanesi:** Sık kullandığınız uygulamaları kütüphaneye ekleyin ve yönetin.
- **Liquid Glass Teması:** Şeffaf ve modern blur efektli görünüm.
- **Arka Planda Çalışma:** Menü çubuğu ikonundan servis kontrolü (Pencere kapalıyken bile çalışır).
- **Protokol Desteği:** SOCKS5, HTTP ve HTTPS desteği.
- **Hızlı Profiller:** Standart, Oyun, Streaming ve Gizlilik için hazır yapılandırmalar.

## Kurulum ve Çalıştırma

### Gereksinimler
- macOS 13.0+
- `ciadpi` (Varsayılan olarak `~/.byedpi/ciadpi` yolunda bulunur)

### Derleme
Uygulamayı derlemek için terminalden `build_app.sh` betiğini çalıştırabilirsiniz:

```bash
chmod +x build_app.sh
./build_app.sh
```

Derlenen uygulama `Build/ByeDPI Manager.app` klasöründe oluşacaktır.

## Katkıda Bulunma

1. Bu repoyu fork edin.
2. Yeni bir feature branch açın (`git checkout -b feature/yeniozellik`).
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni özellik eklendi'`).
4. Branch'inizi push edin (`git push origin feature/yeniozellik`).
5. Pull Request açın.

## Lisans
MIT
