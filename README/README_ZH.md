<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — 开源远程电脑安全与监控系统

AlertRox 是一套开源的电脑安全监控系统，让您可以通过手机全面远程控制与监控电脑。

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

## 🌟 中文

- 🛡️ **电脑后台守护进程:** 开机自启，每10秒发送一次心跳保活。
- 📱 **Flutter 跨平台客户端:** 现代 Material 3 风格，支持高对比度深色和浅色主题。
- ⚡ **Android 桌面小组件 (Widget):** 手机桌面上实时显示电脑在线/离线状态。
- 🔒 **远程控制:** 锁屏、注销当前会话、远程关机。
- 📸 **实时监控:** 截取屏幕画面、摄像头拍照、10秒环境音频录音。
- 💬 **桌面双向聊天:** 手机与电脑之间实时弹出对话窗口。
- 🖼️ **媒体画廊:** 浏览、下载捕获的文件，并支持一键清空全部媒体。
- 🌐 **支持10种语言:** 中文、英语、土耳其语、德语、俄语、西班牙语、阿拉伯语、法语、葡萄牙语、日语。

---

## 🛠️ 安装与部署指南

### 1. Supabase 数据库配置
在 Supabase SQL 编辑器中粘贴并运行 `supabase_schema.sql`。

### 2. 电脑端后台服务安装 (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. 手机端安装 (Android)
直接从 GitHub Actions 下载构建好的 `AlertRox.apk` 安装包。

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
