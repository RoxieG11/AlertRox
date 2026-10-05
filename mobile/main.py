"""
AlertRox — Mobil Uygulama (KivyMD)

Bilgisayarınızın durumunu görün ve uzaktan kontrol edin.
PC'de de çalışır! (Test için)

Kullanım:
    python mobile/main.py
"""

import os
import sys
import threading

# KivyMD'den önce Kivy ayarları (Telefon boyutunu baştan sabitlemek için)
os.environ["KIVY_LOG_LEVEL"] = "warning"

from kivy.config import Config
Config.set('graphics', 'width', '360')
Config.set('graphics', 'height', '760')
Config.set('graphics', 'resizable', '0')

from kivy.lang import Builder
from kivy.clock import Clock, mainthread
from kivy.properties import StringProperty, BooleanProperty
from kivy.core.window import Window

Window.size = (360, 760)

# KivyMD 2.0 SDL2 type-hint fallback (pygame ve diğer window provider uyumluluğu için)
import types
try:
    import kivy.core.window.window_sdl2
except (ModuleNotFoundError, ImportError):
    _mod = types.ModuleType("kivy.core.window.window_sdl2")
    _mod.WindowSDL = object
    sys.modules["kivy.core.window.window_sdl2"] = _mod

from kivymd.app import MDApp
from kivymd.uix.dialog import (
    MDDialog,
    MDDialogHeadlineText,
    MDDialogSupportingText,
    MDDialogButtonContainer,
)
from kivymd.uix.button import MDButton, MDButtonText, MDButtonIcon
from kivymd.uix.snackbar import MDSnackbar, MDSnackbarText

# Proje kök dizinini Python path'ine ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from mobile.i18n import I18n
from agent.supabase_client import AlertRoxClient


# ─────────────────────────────────────────
# KivyMD Arayüz Tanımı (KV Language)
# ─────────────────────────────────────────

KV = """
#:kivy 2.3.0

MDScreen:
    md_bg_color: app.theme_cls.backgroundColor

    MDBoxLayout:
        orientation: "vertical"

        # Üst Bar
        MDTopAppBar:
            type: "small"

            MDTopAppBarTitle:
                text: app.t("title_dashboard")

            MDTopAppBarTrailingButtonContainer:
                MDActionTopAppBarButton:
                    icon: "translate"
                    on_release: app.toggle_language()
                MDActionTopAppBarButton:
                    icon: "refresh"
                    on_release: app.refresh_status()

        MDScrollView:
            do_scroll_x: False
            MDBoxLayout:
                orientation: "vertical"
                padding: "16dp"
                spacing: "14dp"
                adaptive_height: True

                # ── Durum Kartı ──
                MDCard:
                    orientation: "vertical"
                    padding: "20dp"
                    spacing: "12dp"
                    adaptive_height: True
                    style: "elevated"
                    theme_shadow_color: "Custom"
                    shadow_color: [0, 0.7, 0, 0.3] if app.is_online else [0.7, 0, 0, 0.3]

                    MDBoxLayout:
                        adaptive_height: True
                        spacing: "12dp"

                        MDIcon:
                            icon: "desktop-tower-monitor"
                            theme_icon_color: "Custom"
                            icon_color: "green" if app.is_online else "red"
                            pos_hint: {"center_y": 0.5}

                        MDBoxLayout:
                            orientation: "vertical"
                            adaptive_height: True

                            MDLabel:
                                text: app.device_name
                                font_style: "Title"
                                role: "medium"

                            MDLabel:
                                text: app.status_text
                                theme_text_color: "Custom"
                                text_color: "green" if app.is_online else "red"

                        MDIcon:
                            icon: "circle"
                            theme_icon_color: "Custom"
                            icon_color: "green" if app.is_online else "red"
                            pos_hint: {"center_y": 0.5}

                    MDDivider:

                    MDBoxLayout:
                        adaptive_height: True
                        spacing: "8dp"
                        MDIcon:
                            icon: "clock-outline"
                            pos_hint: {"center_y": 0.5}
                        MDLabel:
                            text: app.t("label_last_boot") + ": " + app.last_boot
                            font_style: "Body"
                            role: "medium"

                    MDBoxLayout:
                        adaptive_height: True
                        spacing: "8dp"
                        MDIcon:
                            icon: "heart-pulse"
                            pos_hint: {"center_y": 0.5}
                        MDLabel:
                            text: app.t("label_last_heartbeat") + ": " + app.last_heartbeat
                            font_style: "Body"
                            role: "medium"

                    MDBoxLayout:
                        adaptive_height: True
                        spacing: "8dp"
                        MDIcon:
                            icon: "ip-network"
                            pos_hint: {"center_y": 0.5}
                        MDLabel:
                            text: app.t("label_ip_address") + ": " + app.ip_address
                            font_style: "Body"
                            role: "medium"

                    MDBoxLayout:
                        adaptive_height: True
                        spacing: "8dp"
                        MDIcon:
                            icon: "linux"
                            pos_hint: {"center_y": 0.5}
                        MDLabel:
                            text: app.t("label_os_info") + ": " + app.os_info
                            font_style: "Body"
                            role: "medium"

                # ── Komut Butonları ──
                MDLabel:
                    text: "Uzaktan Kontrol"
                    font_style: "Title"
                    role: "small"
                    adaptive_height: True
                    padding: [0, "8dp", 0, 0]

                # Kapatma & Kilitleme (yan yana)
                MDBoxLayout:
                    adaptive_height: True
                    spacing: "12dp"

                    MDButton:
                        style: "filled"
                        theme_bg_color: "Custom"
                        md_bg_color: "red"
                        on_release: app.confirm_shutdown()
                        size_hint_x: 0.5

                        MDButtonIcon:
                            icon: "power"

                        MDButtonText:
                            text: app.t("btn_shutdown")

                    MDButton:
                        style: "filled"
                        theme_bg_color: "Custom"
                        md_bg_color: "orange"
                        on_release: app.send_command("lock")
                        size_hint_x: 0.5

                        MDButtonIcon:
                            icon: "lock"

                        MDButtonText:
                            text: app.t("btn_lock")

                # Screenshot & Webcam (yan yana)
                MDBoxLayout:
                    adaptive_height: True
                    spacing: "12dp"

                    MDButton:
                        style: "filled"
                        on_release: app.send_command("screenshot")
                        size_hint_x: 0.5

                        MDButtonIcon:
                            icon: "monitor-screenshot"

                        MDButtonText:
                            text: app.t("btn_screenshot")

                    MDButton:
                        style: "filled"
                        on_release: app.send_command("webcam")
                        size_hint_x: 0.5

                        MDButtonIcon:
                            icon: "camera"

                        MDButtonText:
                            text: app.t("btn_webcam")

                # Mikrofon (tam genişlik)
                MDButton:
                    style: "filled"
                    theme_bg_color: "Custom"
                    md_bg_color: "purple"
                    on_release: app.send_command("mic_record", {"duration": 10})

                    MDButtonIcon:
                        icon: "microphone"

                    MDButtonText:
                        text: app.t("btn_mic_record")

                # ── Son İndirilen Medya ──
                MDLabel:
                    text: "İndirilen Medya"
                    font_style: "Title"
                    role: "small"
                    adaptive_height: True
                    padding: [0, "12dp", 0, 0]

                MDCard:
                    orientation: "vertical"
                    padding: "14dp"
                    spacing: "10dp"
                    adaptive_height: True
                    style: "elevated"

                    MDBoxLayout:
                        adaptive_height: True
                        spacing: "8dp"

                        MDIcon:
                            icon: "folder-download"
                            pos_hint: {"center_y": 0.5}

                        MDLabel:
                            text: app.last_media_title
                            font_style: "Title"
                            role: "small"
                            adaptive_height: True

                    MDLabel:
                        text: app.last_media_info
                        font_style: "Body"
                        role: "small"
                        adaptive_height: True

                    MDButton:
                        style: "tonal"
                        on_release: app.open_last_media()
                        disabled: not app.has_media

                        MDButtonIcon:
                            icon: "open-in-new"

                        MDButtonText:
                            text: "Dosyayı Aç / Görüntüle"

                # ── Olay Geçmişi ──
                MDLabel:
                    text: app.t("title_activity_log")
                    font_style: "Title"
                    role: "small"
                    adaptive_height: True
                    padding: [0, "16dp", 0, 0]

                MDCard:
                    orientation: "vertical"
                    padding: "12dp"
                    spacing: "8dp"
                    adaptive_height: True
                    style: "outlined"

                    MDLabel:
                        id: activity_log_label
                        text: app.activity_log_text
                        font_style: "Body"
                        role: "small"
                        adaptive_height: True
"""


# ─────────────────────────────────────────
# Ana Uygulama
# ─────────────────────────────────────────

class AlertRoxApp(MDApp):
    """AlertRox Mobil Uygulaması."""

    # Reactive Properties (arayüz otomatik güncellenir)
    is_online = BooleanProperty(False)
    device_name = StringProperty("...")
    status_text = StringProperty("...")
    last_boot = StringProperty("—")
    last_heartbeat = StringProperty("—")
    ip_address = StringProperty("—")
    os_info = StringProperty("—")
    activity_log_text = StringProperty("Yükleniyor...")

    # Medya İndirme Özellikleri
    last_media_title = StringProperty("Medya İndirmeleri")
    last_media_info = StringProperty("Henüz indirilmiş dosya yok")
    last_media_path = StringProperty("")
    has_media = BooleanProperty(False)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.i18n = I18n("tr")
        self.client = None
        self.dialog = None
        self._refresh_event = None

    def t(self, key: str, **kwargs) -> str:
        """Çeviri kısayolu."""
        return self.i18n.t(key, **kwargs)

    def build(self):
        """Uygulamayı oluştur."""
        self.title = "AlertRox"
        self.theme_cls.primary_palette = "Blue"
        self.theme_cls.theme_style = "Dark"

        return Builder.load_string(KV)

    def on_start(self):
        """Uygulama başladığında çağrılır."""
        # Supabase bağlantısını arka planda kur
        threading.Thread(target=self._init_client, daemon=True).start()

    def _init_client(self):
        """Supabase istemcisini başlat ve ilk veriyi çek."""
        try:
            self.client = AlertRoxClient()
            self._fetch_status()
            self._fetch_activity_log()

            # Her 5 saniyede otomatik yenile
            Clock.schedule_interval(lambda dt: self._auto_refresh(), 5)
        except Exception as e:
            self._show_snackbar(f"Bağlantı hatası: {e}")

    def _auto_refresh(self):
        """Arka planda durumu yenile."""
        threading.Thread(target=self._fetch_status, daemon=True).start()

    def refresh_status(self):
        """Manuel yenileme butonu."""
        threading.Thread(target=self._fetch_all, daemon=True).start()

    def _fetch_all(self):
        """Hem durum hem log'u çek."""
        self._fetch_status()
        self._fetch_activity_log()

    def _fetch_status(self):
        """Cihaz durumunu Supabase'den çek ve arayüzü güncelle."""
        if not self.client:
            return
        try:
            device = self.client.get_device_status()
            if device:
                self.target_device_id = device.get("device_id")
                self._update_ui(device)
        except Exception as e:
            print(f"[AlertRox] Durum çekme hatası: {e}")

    @mainthread
    def _update_ui(self, device: dict):
        """Arayüzü ana thread'de güncelle (Kivy kuralı)."""
        self.device_name = device.get("name", "Bilinmiyor")
        self.is_online = device.get("status") == "online"
        self.status_text = (
            self.t("status_online") if self.is_online else self.t("status_offline")
        )

        # Tarih formatla
        self.last_boot = self._format_time(device.get("last_boot"))
        self.last_heartbeat = self._format_time(device.get("last_heartbeat"))
        self.ip_address = device.get("ip_address", "—")
        self.os_info = device.get("os_info", "—")

    def _fetch_activity_log(self):
        """Olay geçmişini çek."""
        if not self.client:
            return
        try:
            logs = self.client.get_activity_log(limit=10)
            self._update_log_ui(logs)
        except Exception as e:
            print(f"[AlertRox] Log çekme hatası: {e}")

    @mainthread
    def _update_log_ui(self, logs: list):
        """Log arayüzünü güncelle."""
        if not logs:
            self.activity_log_text = "Henüz olay yok"
            return

        lines = []
        for log in logs:
            time_str = self._format_time(log.get("created_at"))
            event = log.get("event_type", "")
            message = log.get("message", "")

            icon = {
                "boot": "🟢",
                "shutdown": "🔴",
                "lock": "🔒",
                "screenshot": "📸",
                "webcam": "📷",
                "mic_record": "🎤",
                "command_executed": "✅",
            }.get(event, "📋")

            lines.append(f"{icon} [{time_str}] {message}")

        self.activity_log_text = "\n".join(lines)

    # ─────────────────────────────────────────
    # Komut Gönderme
    # ─────────────────────────────────────────

    def send_command(self, command_type: str, payload: dict = None):
        """Komutu Supabase'e gönder."""
        if not self.client:
            self._show_snackbar(self.t("msg_no_connection"))
            return

        threading.Thread(
            target=self._send_command_async,
            args=(command_type, payload),
            daemon=True,
        ).start()

    def _send_command_async(self, command_type: str, payload: dict = None):
        """Arka planda komut gönder."""
        try:
            target_id = getattr(self, "target_device_id", None) or self.client.device_id
            cmd = self.client.send_command(
                target_id, command_type, payload
            )
            self._show_snackbar(self.t("msg_command_sent"))

            # Eğer medya komutuysa (screenshot, webcam, mic_record) arka planda sonucu bekle ve indir!
            if command_type in ("screenshot", "webcam", "mic_record") and cmd and "id" in cmd:
                threading.Thread(
                    target=self._wait_and_download_media,
                    args=(cmd["id"], command_type),
                    daemon=True,
                ).start()
        except Exception as e:
            self._show_snackbar(f"{self.t('msg_command_failed')}: {e}")

    def _wait_and_download_media(self, cmd_id: str, cmd_type: str):
        """PC Ajanının hazırladığı medya dosyasını bekler ve telefona/cihaza indirir."""
        import time
        import requests
        from datetime import datetime

        self._update_media_ui("⏳ Hazırlanıyor...", f"{cmd_type} dosyası bekleniyor...", "", False)

        for _ in range(25):  # 25 * 1.5s = ~37 saniye bekle
            time.sleep(1.5)
            cmd = self.client.get_command_status(cmd_id)
            if not cmd:
                continue

            status = cmd.get("status")
            if status == "completed" and cmd.get("result_url"):
                url = cmd["result_url"]
                try:
                    # downloads klasörü
                    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    download_dir = os.path.join(project_root, "downloads")
                    os.makedirs(download_dir, exist_ok=True)

                    ext = "png" if cmd_type == "screenshot" else ("jpg" if cmd_type == "webcam" else "wav")
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    local_filename = f"{cmd_type}_{timestamp}.{ext}"
                    local_path = os.path.join(download_dir, local_filename)

                    r = requests.get(url, timeout=20)
                    if r.status_code == 200:
                        with open(local_path, "wb") as f:
                            f.write(r.content)

                        labels = {
                            "screenshot": "📸 Ekran Görüntüsü",
                            "webcam": "📷 Kamera Fotoğrafı",
                            "mic_record": "🎤 Ses Kaydı",
                        }
                        title = f"{labels.get(cmd_type, 'Dosya')} Hazır!"
                        self._update_media_ui(title, f"Kaydedildi: {local_filename}", local_path, True)
                        self._show_snackbar(f"💾 {local_filename} indirildi!")
                        return
                except Exception as e:
                    self._update_media_ui("❌ İndirme Hatası", str(e), "", False)
                    return

            elif status == "failed":
                err = cmd.get("error_message", "Hata oluştu")
                self._update_media_ui("❌ Başarısız", err, "", False)
                return

        self._update_media_ui("⌛ Zaman Aşımı", "Dosya belirlenen sürede gelemedi", "", False)

    @mainthread
    def _update_media_ui(self, title: str, info: str, path: str, ready: bool):
        self.last_media_title = title
        self.last_media_info = info
        self.last_media_path = path
        self.has_media = ready

    def open_last_media(self):
        """Son indirilen dosyayı sistem varsayılan programıyla açar."""
        if not self.last_media_path or not os.path.exists(self.last_media_path):
            self._show_snackbar("Dosya bulunamadı!")
            return

        import subprocess
        import platform
        sys_name = platform.system()
        try:
            if sys_name == "Linux":
                subprocess.Popen(["xdg-open", self.last_media_path])
            elif sys_name == "Windows":
                os.startfile(self.last_media_path)
            else:
                subprocess.Popen(["open", self.last_media_path])
        except Exception as e:
            self._show_snackbar(f"Açılamadı: {e}")

    def confirm_shutdown(self):
        """Kapatma için onay dialogu göster."""
        self.dialog = MDDialog(
            MDDialogHeadlineText(text=self.t("dialog_shutdown_title")),
            MDDialogSupportingText(text=self.t("dialog_shutdown_message")),
            MDDialogButtonContainer(
                MDButton(
                    MDButtonText(text=self.t("dialog_cancel")),
                    style="text",
                    on_release=lambda x: self.dialog.dismiss(),
                ),
                MDButton(
                    MDButtonText(text=self.t("dialog_confirm")),
                    style="filled",
                    theme_bg_color="Custom",
                    md_bg_color="red",
                    on_release=lambda x: self._do_shutdown(),
                ),
                spacing="8dp",
            ),
        )
        self.dialog.open()

    def _do_shutdown(self):
        """Onaylandıktan sonra kapatma komutunu gönder."""
        if self.dialog:
            self.dialog.dismiss()
        self.send_command("shutdown", {"delay": 60})

    # ─────────────────────────────────────────
    # Dil Değiştirme
    # ─────────────────────────────────────────

    def toggle_language(self):
        """Türkçe ↔ İngilizce arasında geçiş yap."""
        new_lang = "en" if self.i18n.current_lang == "tr" else "tr"
        self.i18n.set_language(new_lang)
        self._show_snackbar(f"🌐 {self.i18n.LANGUAGES[new_lang]}")

        # Arayüzü yeniden oluştur
        self.root.clear_widgets()
        self.root = Builder.load_string(KV)

        # Verileri yeniden yükle
        threading.Thread(target=self._fetch_all, daemon=True).start()

    # ─────────────────────────────────────────
    # Yardımcılar
    # ─────────────────────────────────────────

    @mainthread
    def _show_snackbar(self, text: str):
        """Alt kısımda kısa bilgi mesajı göster."""
        try:
            MDSnackbar(
                MDSnackbarText(text=text),
                y="16dp",
            ).open()
        except Exception:
            print(f"[AlertRox] {text}")

    @staticmethod
    def _format_time(iso_str: str | None) -> str:
        """ISO tarih string'ini okunabilir formata çevir."""
        if not iso_str:
            return "—"
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
            return dt.strftime("%d.%m.%Y %H:%M:%S")
        except (ValueError, AttributeError):
            return iso_str


# ─────────────────────────────────────────
# Çalıştır
# ─────────────────────────────────────────

if __name__ == "__main__":
    AlertRoxApp().run()
