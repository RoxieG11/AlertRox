<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — Système Open-Source de Sécurité et Surveillance PC à Distance

AlertRox est un système de sécurité open-source vous permettant de surveiller et contrôler votre PC à distance depuis votre smartphone.

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

## 🌟 Français

- 🛡️ **Agent d'arrière-plan PC:** Démarre automatiquement au démarrage du système.
- 📱 **Application Flutter:** Interface Material 3 moderne avec thèmes sombre et clair.
- ⚡ **Widget Écran d'Accueil Android:** Statut en direct sur l'écran d'accueil de votre téléphone.
- 🔒 **Commandes à Distance:** Verrouillage de l'écran, déconnexion de session, extinction du PC.
- 📸 **Surveillance:** Captures d'écran, photos webcam, enregistrements audio de 10s.
- 💬 **Chat en Direct:** Messagerie instantanée bidirectionnelle avec le bureau.
- 🖼️ **Galerie Multimédia:** Consulter, télécharger et effacer tous les médias en un clic.
- 🌐 **10 Langues:** Français, Anglais, Turc, Allemand, Russe, Espagnol, Arabe, Portugais, Chinois, Japonais.

---

## 🛠️ Guide d'Installation

### 1. Base de données Supabase
Exécutez `supabase_schema.sql` dans l'éditeur SQL Supabase.

### 2. Configuration de l'Agent PC (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. Application Mobile (Android)
Téléchargez `AlertRox.apk` directement depuis GitHub Actions ou Releases.

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
