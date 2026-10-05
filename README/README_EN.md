<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — Open-Source Remote PC Security & Monitoring System

AlertRox is an open-source security system that allows you to fully monitor and remotely control your PC from your smartphone.

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

> [!NOTE]
> 💡 **Open Source & Completely Free**
> This application is open-source and developed completely free of charge. It contains no ads, subscriptions, or paywalls.

## 🌟 English

- 🛡️ **PC Background Watchdog:** Starts automatically on system boot even before user login.
- 📱 **Flutter Mobile Client:** Modern Material 3 UI with high-contrast Dark and Light themes.
- ⚡ **Android Live Home Screen Widget:** Displays realtime PC online/offline status directly on your phone home screen.
- 🔒 **Remote Security Controls:** Screen Lock, Session Logout, Remote Shutdown.
- 📸 **Remote Surveillance:** Realtime screenshots, webcam captures, 10-second microphone audio recordings.
- 💬 **Desktop Live Chat:** Bidirectional realtime chat popup between PC and smartphone.
- 🖼️ **Media Gallery:** View, open, download, and delete all captured media with a single click.
- 🌐 **10 Languages:** Turkish, English, German, Russian, Spanish, Arabic (RTL), French, Portuguese, Chinese, Japanese.

---

## 🛠️ Installation & Setup

### 1. Supabase Database
Paste and run the contents of `supabase_schema.sql` in your Supabase SQL Editor.

### 2. PC Agent Setup (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. Mobile App (Android)
Download and install the APK directly on your Android device via **[📲 Download AlertRox.apk](https://github.com/RoxieG11/AlertRox/releases/latest/download/AlertRox.apk)**.

Or build from source:

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
