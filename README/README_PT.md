<div align="center">

<img src="../assets/logo.png" width="130" alt="AlertRox Logo" />

# AlertRox — Sistema de Segurança e Monitoramento Remoto de PC

AlertRox é um sistema open-source para monitorar e controlar seu computador remotamente através do celular.

[🇹🇷 Türkçe](README_TR.md) | [🇺🇸 English](README_EN.md) | [🇩🇪 Deutsch](README_DE.md) | [🇷🇺 Русский](README_RU.md) | [🇪🇸 Español](README_ES.md) | [🇸🇦 العربية](README_AR.md) | [🇫🇷 Français](README_FR.md) | [🇧🇷 Português](README_PT.md) | [🇨🇳 中文](README_ZH.md) | [🇯🇵 日本語](README_JA.md)

</div>

---

## 🌟 Português

- 🛡️ **Agente PC:** Inicia automaticamente no boot do sistema operacional.
- 📱 **Aplicativo Flutter:** Design Material 3 com modo escuro e claro de alto contraste.
- ⚡ **Widget Android:** Exibição do status online/offline na tela inicial do celular.
- 🔒 **Controles Remotos:** Bloqueio de tela, encerramento de sessão, desligamento do PC.
- 📸 **Vigilância:** Capturas de tela, fotos da webcam, gravação de áudio de 10 segundos.
- 💬 **Chat no Desktop:** Mensagens em tempo real entre o computador e o smartphone.
- 🖼️ **Galeria de Mídia:** Visualize, baixe e apague todos os arquivos em um clique.
- 🌐 **10 Idiomas:** Português, Inglês, Turco, Alemão, Russo, Espanhol, Árabe, Francês, Chinês, Japonês.

---

## 🛠️ Guia de Instalação

### 1. Banco de Dados Supabase
Execute o script `supabase_schema.sql` no SQL Editor do Supabase.

### 2. Configurar Agente PC (Linux)
```bash
cd AlertRox
bash scripts/install_autostart.sh
```

### 3. Aplicativo Móvel (Android)
Baixe o `AlertRox.apk` pronto das GitHub Actions ou Releases.

```bash
cd app
flutter run -d linux   # Desktop preview
flutter build apk      # Local Android build
```

---

<div align="center">
<sub>AlertRox • Open-Source Remote Security • RoxieG11</sub>
</div>
