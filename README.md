<div align="center">

<img src="assets/logo.png" width="140" alt="AlertRox Logo" />

# 🚨 AlertRox

### Open-Source Remote PC Security, Surveillance & Control System
**Açık Kaynaklı Uzaktan Bilgisayar Güvenlik, İzleme ve Kontrol Sistemi**

[![Android APK CI](https://github.com/RoxieG11/AlertRox/actions/workflows/build_apk.yml/badge.svg)](https://github.com/RoxieG11/AlertRox/actions/workflows/build_apk.yml)
[![Flutter 3](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Storage-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<br/>

[![Download APK](https://img.shields.io/badge/📲_Android_APK_İndir-AlertRox.apk_(v1.5.2)-00F0FF?style=for-the-badge&logo=android&logoColor=black)](https://github.com/RoxieG11/AlertRox/releases/latest/download/AlertRox.apk)

---

### 🌐 Select Language / Dil Seçimi

[🇹🇷 Türkçe](README/README_TR.md) | [🇺🇸 English](README/README_EN.md) | [🇩🇪 Deutsch](README/README_DE.md) | [🇷🇺 Русский](README/README_RU.md) | [🇪🇸 Español](README/README_ES.md) | [🇸🇦 العربية](README/README_AR.md) | [🇫🇷 Français](README/README_FR.md) | [🇧🇷 Português](README/README_PT.md) | [🇨🇳 中文](README/README_ZH.md) | [🇯🇵 日本語](README/README_JA.md)

---

</div>

> [!NOTE]
> 💡 **Açık Kaynak & Tamamen Ücretsiz / Open Source & Free**
> Bu uygulama açık kaynaklı ve tamamen ücretsiz şekilde geliştirilmiştir. Hiçbir abonelik, reklam veya gizli ücret içermez.
> *This application is developed as an open-source project and is completely free of charge. No subscriptions, ads, or hidden fees.*

## 📌 What is AlertRox? / AlertRox Nedir?

**AlertRox**, bilgisayarınızın güvenliğini dünyanın neresinde olursanız olun akıllı telefonunuzdan takip etmenizi sağlayan modern, açık kaynaklı bir uzaktan yönetim sistemidir.

- 🖥️ **PC Gözcüsü:** Bilgisayar açıldığı an (kullanıcı giriş yapmasa dahi) arka planda otomatik uyanır, IP ve açılış saatini bildirir.
- 📱 **Mobil Uygulama:** Flutter ile geliştirilmiş, 10 dilli, Açık/Koyu temalı, zengin özellikli kontrol merkezi.
- ⚡ **Android Widget:** Telefonun ana ekranına yerleştirilen canlı açık/kapalı durum göstergesi.

---

## ⚡ Core Features / Temel Özellikler

| Özellik | Açıklama |
| :--- | :--- |
| 🔒 **Uzaktan Kilitleme** | Tek tuşla bilgisayarın ekranını anında kilitler (`loginctl lock-session`). |
| 🚪 **Oturumu Kapatma** | Aktif kullanıcı oturumunu uzaktan sonlandırır. |
| 🛑 **Uzaktan Kapatma** | Bilgisayarı uzaktan güvenli şekilde kapatır (`shutdown`). |
| 📸 **Ekran Görüntüsü** | PC ekranının o anki görüntüsünü çeker ve anında telefona iletir. |
| 📷 **Webcam Çekimi** | Bilgisayar kamerasından o an masada oturan kişinin fotoğrafını çeker. |
| 🎙️ **Mikrofon Kaydı** | 10 saniyelik ortam sesini kaydeder ve dinlemenizi sağlar. |
| 💬 **Canlı Sohbet** | PC ekranında masaüstü sohbet penceresi açarak karşılıklı anlık mesajlaşma sağlar. |
| 🖼️ **Medya Yönetimi** | Çekilen tüm görüntü ve sesleri listeler; tek tuşla tümünü temizleme imkanı sunar. |
| 📱 **Home Screen Widget** | Telefon ana ekranında PC'nin açık mı kapalı mı olduğunu canlı gösterir. |
| 🔋 **Pil & Güç Bildirimi** | Laptop prizden çekildiğinde veya pil %20 altına düştüğünde telefona anında acil uyarı gönderir. |
| 🔊 **Uzaktan Ses & Medya** | PC ses seviyesini telefon üzerinden kaydırıcı veya adım tuşlarıyla değiştirir, sessize alır ve medya oynatıcıyı kontrol eder. |
| 📦 **Uygulama Yöneticisi** | PC'de açık olan pencereleri listeler ve sonlandırır; yüklü masaüstü uygulamalarını tek tıkla başlatır. |

---

## 🏗️ Architecture / Sistem Mimarisi

```text
[ Android Smartphone / AlertRox App ]
          │                    ▲
  (REST & Realtime)     (Live WebSocket)
          ▼                    │
    [ ☁️ Supabase Cloud (PostgreSQL RLS & Storage) ]
          ▲                    │
     (Heartbeat)         (Command Poll)
          │                    ▼
    [ 🖥️ PC Agent (Linux / Windows Background Service) ]
```

---

## 🛠️ Servis ve Sağlık Yönetimi (Linux)

AlertRox PC Agent'ı bir **systemd kullanıcı servisi** (`systemctl --user`) olarak çalışır.

```bash
# Servis durumunu ve sağlık kontrollerini görüntüle:
./scripts/alertrox-status.sh

# Ajan kendi kendine test ve donanım/araç teşhisi (Self-Test):
./venv/bin/python -m agent.selftest

# Güvenlik ve RLS sızma testi:
./venv/bin/python scripts/security_check.py

# Servisi yeniden başlatma:
systemctl --user restart alertrox.service

# Servisi durdurma:
systemctl --user stop alertrox.service

# Canlı servis loglarını takip etme:
journalctl --user -u alertrox.service -f
```

> [!TIP]
> **CachyOS / Arch Linux Kullanıcıları İçin:**
> Ses ve medya denetiminde en iyi kararlılık için sisteminizde `pipewire` veya `pulseaudio` araçlarının bulunması yeterlidir:
> ```bash
> sudo pacman -S pipewire libpulse
> ```

---

## 🚀 Quick Start / Hızlı Kurulum

### 1️⃣ Supabase Kurulumu
1. Ücretsiz bir [Supabase](https://supabase.com) projesi açın.
2. [`supabase_schema.sql`](supabase_schema.sql) ve ardından [`supabase_v15_features_migration.sql`](supabase_v15_features_migration.sql) dosyalarını Supabase paneli → **SQL Editor** alanına yapıştırıp **Run** butonuna basın.

### 2️⃣ PC Ajanının Kurulumu (Bilgisayarınızda)
```bash
# Projeyi klonlayın
git clone https://github.com/RoxieG11/AlertRox.git
cd AlertRox

# Sanal ortam oluşturup paketleri yükleyin
python -m venv venv
./venv/bin/pip install -r requirements.txt

# .env dosyasını oluşturun ve Supabase bilgilerinizi girin
cp .env.example .env
nano .env

# Otomatik başlatma servisini kurun
bash scripts/install_autostart.sh
```

### 3️⃣ Android APK Kurulumu (Telefonunuzda)
- Telefonunuzdan doğrudan **[📲 AlertRox.apk İndir](https://github.com/RoxieG11/AlertRox/releases/latest/download/AlertRox.apk)** linkine dokunarak güncel APK'yı indirin ve kurun.
- Uygulama içindeki **Ayarlar** kısmından Supabase URL ve Key bilgilerinizi kaydedin.
- Telefon ana ekranına uzun basarak **AlertRox Widget**'ını masaüstünüze ekleyin!

---

### 🌐 Uluslararasılaştırma (i18n) & Katkı Kuralı
Projeye yeni metin veya arayüz özelliği eklenirken tüm dillerin (10 dil: `tr`, `en`, `de`, `ru`, `es`, `ar`, `fr`, `pt`, `zh`, `ja`) eksiksiz çevrilmesi zorunludur:
```bash
cd app
dart run scripts/check_i18n.dart
flutter test
```
> [!IMPORTANT]
> `check_i18n.dart` doğrulaması veya `flutter test` geçmeden pull request kabul edilmez. Sabit hardcoded metinler ve çevrilmemiş İngilizce kopyalar derleme öncesinde otomatik engellenir.

---

<div align="center">
<sub>Developed with ❤️ by RoxieG11 • AlertRox Open-Source Security</sub>
</div>
