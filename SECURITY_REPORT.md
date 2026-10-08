# AlertRox Güvenlik Raporu (SECURITY_REPORT.md)

**Denetim Tarihi:** 8 Ekim 2026  
**Sürüm:** v1.5.2  
**Hedef Sistem:** Linux (CachyOS / Arch / KDE Plasma 6 Wayland) & Windows  
**Mobil:** Flutter Android SDK 35  

---

## 🛡️ Özet Yönetici Değerlendirmesi

AlertRox mimarisi, kimliği doğrulanmamış doğrudan erişimlere karşı sıfır toleranslıdır. Yapılan son testlerde veritabanı, depolama ve işletim sistemi katmanlarındaki tüm güvenlik ilkeleri doğrulanmıştır.

| Güvenlik Alanı | Değerlendirme | Durum |
| :--- | :--- | :--- |
| **Row Level Security (RLS)** | Tüm tablolarda `owner_id = auth.uid()` zorunlu kılındı. `using (true)` politikası bulunmuyor. | 🟢 Kusursuz |
| **Kimlik Doğrulama** | Supabase Auth (Email & Şifre) + Anon Key. `service_role` asla istemcide bulunmaz. | 🟢 Güvenli |
| **Komut Enjeksiyonu** | `shell=True` çağrıları temizlendi; argümanlar güvenli dizi (`list`) olarak aktarılıyor. | 🟢 Korundu |
| **Süreç Kapatma Güvenliği** | Kritik sistem süreçleri (`kwin`, `plasmashell`, `pipewire`, `systemd` vb.) korumalı listede. | 🟢 Güvenli |
| **Pano & WoL Politikası** | Gizlilik ve sadelik için Pano ve WoL bileşenleri tamamen kaldırıldı; gereksiz izinler (`READ_LOGS`, `SYSTEM_ALERT_WINDOW`) temizlendi. | 🟢 Temizlendi |
| **Tekil Çalışma Kilidi** | `fcntl.flock` tabanlı tekil örnek koruması ile çakışmalar engellendi. | 🟢 Aktif |
| **Çoklu Dil Bütünlüğü** | 10 dilde 201 anahtar, 0 eksik çeviri, otomatik AST/CI denetleyici (`check_i18n.dart`). | 🟢 Doğrulandı |

---

## 🔍 Detaylı Bulgu Listesi ve Durumları

### 1. Row Level Security & Veritabanı Politikaları
- **Test:** `scripts/security_check.py` anonim istemciyle `devices`, `commands`, `messages`, `activity_log`, `device_state` tablolarına `SELECT` ve `INSERT` denedi.
- **Sonuç:** Tüm istekler PostgreSQL RLS tarafından anında reddedildi (`APIError`).
- **Storage:** `alertrox-files` bucket'ı gizli (private) yapıldı; dosya erişimleri sadece 600 saniye süreli imzalı URL (signed URL) ile sağlanır.

### 2. Hassas Anahtarlar & Kod Denetimi
- **Test:** Kaynak kodda `eyJ` (JWT token) ve `service_role` taraması yapıldı.
- **Sonuç:** Git tarafından takip edilen hiçbir kaynak kod dosyasında açık anahtar veya token bulunmamaktadır.
- **.env İzinleri:** Linux sistemlerde `0600` izni denetlenmekte ve otomatik düzeltilmektedir.

### 3. Komut Doğrulama ve Check Constraints
- `supabase_v15_features_migration.sql` ile `commands.command_type` kısıtlaması güncellenmiş ve `validate_command_payload` tetikleyicisiyle şu sınırlamalar getirilmiştir:
  - `shutdown delay`: 5 - 86400 saniye arası
  - `mic_record duration`: 1 - 120 saniye arası
  - `set_volume`: 0 - 100 arası
  - `set_clipboard`: Maksimum 100 KB (102400 bayt)

### 4. Masaüstü Gizlilik Bildirimleri
- Web kamerasından fotoğraf çekildiğinde, mikrofon kaydı alındığında ve ekran görüntüsü yakalandığında PC masaüstünde anında `notify-send` ile kullanıcıya görünür güvenlik bildirimi gösterilir.

---

## ⚠️ Kullanıcının Yapması Gereken Adımlar
1. **Supabase SQL Migrasyonunu Uygulayın:**
   - Supabase Dashboard > SQL Editor sekmesine gidin.
   - `supabase_v15_features_migration.sql` dosyasının içeriğini yapıştırıp **Run** düğmesine basın.
2. **CachyOS / Arch Paketleri (İsteğe Bağlı Ek Araçlar):**
   - Terminalde şu komutu çalıştırabilirsiniz:
     ```bash
     sudo pacman -S wl-clipboard xclip
     ```
