<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — オープンソース遠隔PCセキュリティ＆監視システム

AlertRoxは、スマートフォンからPCを完全に遠隔監視・操作できるオープンソースのセキュリティシステムです。

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

## 🌟 日本語

- 🛡️ **PCバックグラウンドエージェント:** PC起動時に自動起動し、10秒ごとに稼働信号を送信。
- 📱 **Flutterモバイルアプリ:** Material 3モダンデザイン、ダーク＆ライトモード対応。
- ⚡ **Androidホーム画面ウィジェット:** スマホのホーム画面でPCの稼働状態をリアルタイム表示。
- 🔒 **遠隔操作:** 画面ロック、セッションログアウト、PCシャットダウン。
- 📸 **監視機能:** スクリーンショット撮影、ウェブカメラ撮影、10秒間の音声録音。
- 💬 **デスクトップライブチャット:** PCとスマホ間の双方向リアルタイムチャット。
- 🖼️ **メディアギャラリー:** 保存された写真や音声を閲覧・ダウンロード・ワンタップで全削除。
- 🌐 **10言語対応:** 日本語、トルコ語、英語、ドイツ語、ロシア語、スペイン語、アラビア語、フランス語、ポルトガル語、中国語。

---

## 🛠️ セットアップガイド

### 1. Supabaseデータベース設定
Supabase SQLエディタで `supabase_schema.sql` を実行します。

### 2. PCエージェントのセットアップ (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. モバイルアプリ (Android)
GitHub Actionsからビルド済みの `AlertRox.apk` をダウンロードします。

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
