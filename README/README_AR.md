<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — نظام مفتوح المصدر لأمان ومراقبة الكمبيوتر عن بُعد

نظام أمان متقدم يتيح لك التحكم الكامل ومراقبة جهاز الكمبيوتر الخاص بك عن بُعد من هاتفك الذكي.

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

## 🌟 العربية

- 🛡️ **عميل خلفية الكمبيوتر:** يبدأ تلقائيًا مع تشغيل النظام ويرسل نبضات كل 10 ثوانٍ.
- 📱 **تطبيق Flutter:** تصميم عصري مع دعم كامل للوضع الداكن والفاتح والكتابة من اليمين لليسار (RTL).
- ⚡ **أداة الشاشة الرئيسية للأندرويد (Widget):** عرض حالة الكمبيوتر مباشرة على الشاشة الرئيسية.
- 🔒 **التحكم عن بُعد:** قفل الشاشة، تسجيل الخروج، إيقاف تشغيل الكمبيوتر.
- 📸 **المراقبة الفورية:** لقطات شاشة، صور الكاميرا، وتسجيل صوتي لمدة 10 ثوانٍ.
- 💬 **محادثة سطح المكتب:** شاشة دردشة فورية ثنائية الاتجاه بين الكمبيوتر والهاتف.
- 🖼️ **معرض الوسائط:** استعراض، تنزيل وحذف جميع الوسائط بنقرة واحدة.
- 🌐 **10 لغات:** العربية، التركية، الإنجليزية، الألمانية، الروسية، الإسبانية، الفرنسية، البرتغالية، الصينية، اليابانية.

---


---

## 📸 لقطات الشاشة والدليل المرئي

<div align="center">

| 🖥️ Dashboard | 📦 Apps | 🖼️ Media |
|:---:|:---:|:---:|
| <img src="../assets/screenshots/ar/dashboard.png" width="230" alt="Dashboard" /> | <img src="../assets/screenshots/ar/apps.png" width="230" alt="Apps" /> | <img src="../assets/screenshots/ar/media.png" width="230" alt="Media" /> |

| 🔊 Volume | ⚡ Widget | 🛠️ Supabase SQL |
|:---:|:---:|:---:|
| <img src="../assets/screenshots/ar/volume.png" width="230" alt="Volume" /> | <img src="../assets/screenshots/ar/widget.png" width="230" alt="Widget" /> | <img src="../assets/screenshots/ar/supabase.png" width="380" alt="Supabase Setup" /> |

</div>

## 🛠️ دليل التثبيت

### 1. قاعدة بيانات Supabase
قم بتشغيل كود `supabase_schema.sql` داخل محرر SQL في Supabase.

<div align="center">
  <img src="../assets/screenshots/ar/supabase.png" width="85%" alt="Supabase Setup" />
</div>

### 2. إعداد عميل الكمبيوتر (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. تطبيق الهاتف (Android)
قم بتنزيل ملف `AlertRox.apk` الجاهز من مخرجات GitHub Actions.

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
