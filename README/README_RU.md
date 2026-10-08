<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — Система удаленного мониторинга и безопасности ПК

AlertRox — это система с открытым исходным кодом для удаленного мониторинга и управления компьютером со смартфона.

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

## 🌟 Русский

- 🛡️ **Фоновый агент ПК:** Автозапуск при включении системы еще до входа пользователя.
- 📱 **Flutter клиент:** Дизайн Material 3 с поддержкой темной и светлой тем.
- ⚡ **Виджет Android:** Индикатор онлайн/оффлайн на главном экране телефона.
- 🔒 **Удаленное управление:** Блокировка экрана, выход из сеанса, выключение ПК.
- 📸 **Наблюдение:** Скриншоты экрана, снимки с веб-камеры, запись звука (10 сек).
- 💬 **Живой чат:** Мгновенный обмен сообщениями между ПК и мобильным приложением.
- 🖼️ **Медиагалерея:** Просмотр, загрузка и удаление всех записей в один клик.
- 🌐 **10 языков:** Русский, Турецкий, Английский, Немецкий, Испанский, Арабский, Французский, Португальский, Китайский, Японский.

---


---

## 📸 Скриншоты и визуальное руководство

<div align="center">

| 🖥️ Dashboard | 📦 Apps | 🖼️ Media |
|:---:|:---:|:---:|
| <img src="../assets/screenshots/ru/dashboard.png" width="230" alt="Dashboard" /> | <img src="../assets/screenshots/ru/apps.png" width="230" alt="Apps" /> | <img src="../assets/screenshots/ru/media.png" width="230" alt="Media" /> |

| 🔊 Volume | ⚡ Widget | 🛠️ Supabase SQL |
|:---:|:---:|:---:|
| <img src="../assets/screenshots/ru/volume.png" width="230" alt="Volume" /> | <img src="../assets/screenshots/ru/widget.png" width="230" alt="Widget" /> | <img src="../assets/screenshots/ru/supabase.png" width="380" alt="Supabase Setup" /> |

</div>

## 🛠️ Руководство по установке

### 1. База данных Supabase
Вставьте и выполните `supabase_schema.sql` в редакторе SQL Supabase.

<div align="center">
  <img src="../assets/screenshots/ru/supabase.png" width="85%" alt="Supabase Setup" />
</div>

### 2. Настройка агента ПК (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. Мобильное приложение (Android)
Скачайте готовый `AlertRox.apk` из GitHub Actions или Releases.

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
