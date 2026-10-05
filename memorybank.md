# 🧠 AlertRox — Memory Bank

> Bu dosya projenin tüm bağlamını, mimari kararlarını ve ilerlemesini takip eder.
> Her oturumda bu dosyaya bakılarak proje durumu hatırlanır.

---

## 📌 Proje Özeti

| Alan | Değer |
|---|---|
| **Proje Adı** | AlertRox |
| **Amaç** | Bilgisayar açıldığında telefona anlık bildirim göndermek; uzaktan kapatma/kilitleme/izleme |
| **Hedef Platform** | Linux (PC Ajanı) · Android (Mobil Uygulama - APK) |
| **Dil / Teknoloji** | **%100 Python** (Desktop Agent + KivyMD Mobil App) |
| **Backend / Köprü** | **Supabase** (PostgreSQL + Realtime + Storage) |
| **Derleyici (Mobil)** | **Buildozer** (Python → Android APK) |
| **Repo** | GitHub — `AlertRox` (sürükle-bırak yöntemiyle, `.env` dahil edilmez!) |
| **Tarih** | 2026-09-24 |
| **Durum** | 🟢 Supabase şeması hazırlanıyor |

---

## 🎯 Özellik Listesi

### v1.0 — Temel Özellikler
| # | Özellik | PC Agent | Mobil App | Durum |
|---|---------|----------|-----------|-------|
| 1 | PC açıldığında bildirim | Supabase'e "online" yazar | Anlık bildirim alır | ⬜ |
| 2 | Canlı açık/kapalı göstergesi | Her 10sn heartbeat gönderir | 🟢/🔴 gösterir | ⬜ |
| 3 | Uzaktan bilgisayarı kapatma | `shutdown` komutunu dinler/uygular | "Kapat" butonu | ⬜ |
| 4 | Uzaktan ekran kilitleme | `lock` komutunu dinler/uygular | "Kilitle" butonu | ⬜ |
| 5 | Ekran görüntüsü alma | SS alıp Supabase Storage'a yükler | SS'i görüntüler | ⬜ |

### v1.5 — Gelişmiş İzleme
| # | Özellik | PC Agent | Mobil App | Durum |
|---|---------|----------|-----------|-------|
| 6 | WebCam fotoğraf çekme | Kameradan foto çekip yükler | Fotoğrafı görüntüler | ⬜ |
| 7 | Mikrofon dinleme/kaydetme | Ses kaydedip yükler | Kaydı dinler | ⬜ |

---

## 🏗️ Sistem Mimarisi

```
 ┌───────────────────────────┐                     ┌──────────────────────────┐
 │   Evdeki Linux PC         │                     │  📱 Android Telefon      │
 │                           │                     │  (KivyMD + Buildozer)    │
 │  • Boot → "online" yaz    │                     │                          │
 │  • 10sn'de bir heartbeat  │                     │  • Durumu gör (🟢/🔴)    │
 │  • Komut tablosunu dinle  │                     │  • Kapat/Kilitle butonları│
 │  • Komutu çalıştır        │                     │  • SS/Foto/Ses görüntüle │
 │  • Sonucu Storage'a yükle │                     │                          │
 └────────────┬──────────────┘                     └────────────┬─────────────┘
              │                                                 │
              ▼                                                 ▼
       ┌──────────────────────────────────────────────────────────────┐
       │                  ☁️ Supabase Cloud (Ücretsiz)                │
       │                                                              │
       │   📋 Tablo: devices        (cihaz durumu + heartbeat)        │
       │   📋 Tablo: commands       (komut kuyruğu)                   │
       │   📋 Tablo: activity_log   (olay geçmişi)                    │
       │   📦 Storage: alertrox-files (SS, foto, ses dosyaları)       │
       └──────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Supabase Veritabanı Şeması

### devices tablosu
- `id` (uuid) — Birincil anahtar
- `device_id` (text, unique) — Makine tanımlayıcı
- `name` (text) — Kullanıcı verdiği isim
- `status` (text) — "online" / "offline"
- `last_boot` (timestamptz) — Son açılış zamanı
- `last_heartbeat` (timestamptz) — Son kalp atışı (canlı gösterge)
- `ip_address` (text) — Yerel IP adresi
- `os_info` (text) — İşletim sistemi bilgisi

### commands tablosu
- `id` (uuid) — Birincil anahtar
- `device_id` (text) — Hedef cihaz
- `command_type` (text) — "shutdown" / "lock" / "screenshot" / "webcam" / "mic_record"
- `status` (text) — "pending" / "executing" / "completed" / "failed"
- `payload` (jsonb) — Ek parametreler (örn: mikrofon süresi)
- `result_url` (text) — Sonuç dosyasının Storage URL'i
- `created_at` / `executed_at` (timestamptz)

### activity_log tablosu
- `id` (uuid) — Birincil anahtar
- `device_id` (text) — Kaynak cihaz
- `event_type` (text) — "boot" / "shutdown" / "heartbeat_lost" / "command_executed"
- `message` (text) — Olay açıklaması
- `created_at` (timestamptz)

### Storage
- Bucket: `alertrox-files` — Ekran görüntüleri, webcam fotoğrafları, ses kayıtları

---

## 🔒 Güvenlik

1. **`.env` Koruması:** Supabase URL ve Key yalnızca `.env` dosyasında, GitHub'a asla yüklenmez.
2. **GitHub'a sürükle-bırak:** `.env` dosyası ASLA seçilmez / yüklenmez.
3. **RLS (Row Level Security):** Tablolara yalnızca `service_role` key ile erişim izni.
4. **Storage Güvenliği:** Bucket private, dosyalara yalnızca signed URL ile erişim.

---

## 📁 Proje Dosya Yapısı

```
AlertRox/
├── .gitignore
├── .env.example
├── .env                       # (GitHub'a ASLA yüklenmez)
├── README.md
├── memorybank.md
├── requirements.txt
├── supabase_schema.sql        # Supabase SQL Editor'e yapıştırılacak
│
├── agent/                     # 🖥️ PC arka plan servisi
│   ├── __init__.py
│   ├── main.py                # Ana döngü (heartbeat + komut dinleme)
│   ├── supabase_client.py     # Supabase bağlantı katmanı
│   ├── system_actions.py      # shutdown, lock, screenshot, webcam, mic
│   └── alertrox.service       # systemd servis tanımı
│
├── mobile/                    # 📱 KivyMD Android uygulaması (PC'de de çalışır!)
│   ├── main.py                # Arayüz + Supabase bağlantısı
│   ├── buildozer.spec         # APK derleme ayarları
│   ├── i18n.py                # Çoklu dil yöneticisi
│   ├── locales/               # Dil dosyaları
│   │   ├── tr.json            # 🇹🇷 Türkçe
│   │   └── en.json            # 🇬🇧 İngilizce
│   └── assets/                # İkonlar, görseller
│
└── scripts/
    └── install_agent.sh       # Tek tıkla kurulum
```

---

## 🌐 Çoklu Dil Desteği (i18n)

- JSON tabanlı basit çeviri sistemi (`locales/tr.json`, `locales/en.json`)
- Uygulama içinde dil değiştirme butonu / ayar
- Yeni dil eklemek = yeni bir `.json` dosyası eklemek kadar kolay
- Varsayılan dil: Türkçe

---

## 🧪 Geliştirme & Test Stratejisi

1. **PC'de geliştir ve test et:** KivyMD uygulaması Linux üzerinde doğrudan `python mobile/main.py` ile çalışır.
2. **Her şey stabil olunca:** `buildozer android debug` ile APK'ya çevir.
3. **Telefona yükle ve final test:** APK'yı telefona atıp gerçek ortamda doğrula.

---

## 📝 Oturum Notları

### Oturum 1 — 2026-09-24
- Proje fikri belirlendi
- Mimari: %100 Python (KivyMD + Buildozer + Supabase)
- Firebase/VDS yerine Supabase seçildi (ücretsiz, kolay)
- GitHub'a sürükle-bırak yöntemi kullanılacak (`.env` dahil edilmeyecek!)
- Özellikler kesinleşti: Kapatma, Kilitleme, Boot bildirimi, Canlı gösterge, SS, WebCam, Mikrofon
- Supabase projesi oluşturuldu
- Supabase SQL şeması hazırlandı (3 tablo + Storage bucket)
- Mobil uygulama önce PC'de test edilecek, sonra APK'ya çevrilecek
- Çoklu dil desteği: Türkçe 🇹🇷 + İngilizce 🇬🇧 (JSON tabanlı i18n)
- **Sonraki adım:** Supabase SQL çalıştırılacak → Storage bucket oluşturulacak → PC Agent kodları → Mobil App
