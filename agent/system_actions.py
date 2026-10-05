"""
AlertRox — Sistem Komutları

Bilgisayar üzerinde çalıştırılacak tüm komutlar burada tanımlanır.
Linux ve Windows otomatik olarak algılanır (cross-platform).
"""

import os
import platform
import subprocess
import tempfile
from datetime import datetime


SYSTEM = platform.system()  # "Linux" veya "Windows"


# ─────────────────────────────────────────
# Bilgisayarı Kapatma
# ─────────────────────────────────────────

def shutdown(delay_seconds: int = 60) -> tuple[bool, str]:
    """
    Bilgisayarı belirtilen saniye sonra kapatır.
    Dönüş: (başarılı_mı, mesaj)
    """
    try:
        if SYSTEM == "Linux":
            delay_minutes = max(1, delay_seconds // 60)
            subprocess.run(
                ["shutdown", "-h", f"+{delay_minutes}"],
                check=True,
            )
        elif SYSTEM == "Windows":
            subprocess.run(
                ["shutdown", "/s", "/t", str(delay_seconds)],
                check=True,
            )
        else:
            return False, f"Desteklenmeyen işletim sistemi: {SYSTEM}"

        return True, f"Bilgisayar {delay_seconds} saniye sonra kapanacak"
    except Exception as e:
        return False, f"Kapatma hatası: {e}"


def cancel_shutdown() -> tuple[bool, str]:
    """Zamanlanmış kapatmayı iptal eder."""
    try:
        if SYSTEM == "Linux":
            subprocess.run(["shutdown", "-c"], check=True)
        elif SYSTEM == "Windows":
            subprocess.run(["shutdown", "/a"], check=True)

        return True, "Kapatma iptal edildi"
    except Exception as e:
        return False, f"İptal hatası: {e}"


# ─────────────────────────────────────────
# Ekranı Kilitleme
# ─────────────────────────────────────────

def lock_screen() -> tuple[bool, str]:
    """Ekranı kilitler. Birden fazla yöntem dener (en geniş uyumluluk)."""
    try:
        if SYSTEM == "Linux":
            # Sırayla farklı kilitleme yöntemlerini dene
            # Böylece KDE, GNOME, XFCE, Hyprland, i3 vs. hepsinde çalışır
            lock_commands = [
                ["loginctl", "lock-session"],           # systemd (CachyOS, Arch, Ubuntu, Fedora...)
                ["xdg-screensaver", "lock"],             # XDG uyumlu tüm masaüstleri
                ["dbus-send", "--type=method_call",      # GNOME / Cinnamon
                 "--dest=org.gnome.ScreenSaver",
                 "/org/gnome/ScreenSaver",
                 "org.gnome.ScreenSaver.Lock"],
                ["qdbus", "org.freedesktop.ScreenSaver", # KDE Plasma
                 "/ScreenSaver", "Lock"],
                ["xscreensaver-command", "-lock"],       # XScreenSaver (eski sistemler)
                ["i3lock"],                              # i3wm
                ["swaylock"],                            # Sway (Wayland)
            ]

            for cmd in lock_commands:
                try:
                    result = subprocess.run(
                        cmd,
                        check=True,
                        capture_output=True,
                        timeout=5,
                    )
                    return True, f"Ekran kilitlendi ({cmd[0]})"
                except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                    continue

            return False, "Uyumlu ekran kilitleme aracı bulunamadı"

        elif SYSTEM == "Windows":
            subprocess.run(
                ["rundll32.exe", "user32.dll,LockWorkStation"],
                check=True,
            )
        else:
            return False, f"Desteklenmeyen işletim sistemi: {SYSTEM}"

        return True, "Ekran kilitlendi"
    except Exception as e:
        return False, f"Kilitleme hatası: {e}"


# ─────────────────────────────────────────
# Ekran Görüntüsü Alma
# ─────────────────────────────────────────

def take_screenshot() -> tuple[bool, str, str | None]:
    """
    Ekran görüntüsü alır ve geçici dosyaya kaydeder.
    Wayland (CachyOS/KDE/Hyprland), X11 ve Windows'u otomatik destekler.
    Dönüş: (başarılı_mı, mesaj, dosya_yolu)
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = os.path.join(tempfile.gettempdir(), f"alertrox_ss_{timestamp}.png")

    if SYSTEM == "Linux":
        # Wayland masaüstlerinde (CachyOS KDE Plasma / Hyprland) mss siyah ekran verir.
        # Bu yüzden yerel Wayland/X11 araçlarını sırayla deneriz:
        linux_screenshot_tools = [
            ["spectacle", "-b", "-n", "-o", file_path],        # KDE Plasma (CachyOS varsayılanı)
            ["grim", file_path],                               # Hyprland / Sway / Wayland
            ["gnome-screenshot", "-f", file_path],             # GNOME
            ["scrot", file_path],                              # X11
            ["import", "-window", "root", file_path],          # ImageMagick
        ]

        for cmd in linux_screenshot_tools:
            try:
                res = subprocess.run(
                    cmd,
                    check=True,
                    capture_output=True,
                    timeout=6,
                )
                if os.path.exists(file_path) and os.path.getsize(file_path) > 1000:
                    return True, f"Ekran görüntüsü alındı ({cmd[0]})", file_path
            except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                continue

    # Windows veya X11 mss fallback
    try:
        import mss
        from PIL import Image

        with mss.mss() as sct:
            screenshot = sct.grab(sct.monitors[0])
            img = Image.frombytes("RGB", screenshot.size, screenshot.bgra, "raw", "BGRX")
            img.save(file_path, "PNG")

        if os.path.exists(file_path) and os.path.getsize(file_path) > 1000:
            return True, "Ekran görüntüsü alındı (mss)", file_path
    except Exception as e:
        return False, f"Ekran görüntüsü hatası: {e}", None

    return False, "Ekran görüntüsü yakalama aracı bulunamadı", None


# ─────────────────────────────────────────
# WebCam Fotoğraf Çekme
# ─────────────────────────────────────────

def capture_webcam() -> tuple[bool, str, str | None]:
    """
    Web kamerasından fotoğraf çeker.
    Dönüş: (başarılı_mı, mesaj, dosya_yolu)
    """
    try:
        import cv2

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_path = os.path.join(tempfile.gettempdir(), f"alertrox_cam_{timestamp}.jpg")

        cap = cv2.VideoCapture(0)

        if not cap.isOpened():
            return False, "Web kamerası bulunamadı veya kullanımda", None

        # Kameranın ısınması için birkaç kare yakala
        for _ in range(5):
            cap.read()

        ret, frame = cap.read()
        cap.release()

        if not ret:
            return False, "Kameradan görüntü alınamadı", None

        cv2.imwrite(file_path, frame)
        return True, "Web kamerasından fotoğraf çekildi", file_path
    except ImportError:
        return False, "opencv-python yüklü değil: pip install opencv-python", None
    except Exception as e:
        return False, f"Kamera hatası: {e}", None


# ─────────────────────────────────────────
# Mikrofon Kayıt
# ─────────────────────────────────────────

def record_microphone(duration_seconds: int = 10) -> tuple[bool, str, str | None]:
    """
    Mikrofondan ses kaydeder.
    Dönüş: (başarılı_mı, mesaj, dosya_yolu)
    """
    try:
        import sounddevice as sd
        from scipy.io import wavfile
        import numpy as np

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_path = os.path.join(tempfile.gettempdir(), f"alertrox_mic_{timestamp}.wav")

        sample_rate = 44100  # CD kalitesi

        print(f"[AlertRox] Mikrofon kaydı başladı ({duration_seconds} saniye)...")
        recording = sd.rec(
            int(duration_seconds * sample_rate),
            samplerate=sample_rate,
            channels=1,
            dtype=np.int16,
        )
        sd.wait()  # Kayıt bitene kadar bekle

        wavfile.write(file_path, sample_rate, recording)
        print(f"[AlertRox] Mikrofon kaydı tamamlandı: {file_path}")

        return True, f"{duration_seconds} saniye ses kaydedildi", file_path
    except ImportError:
        return False, "sounddevice/scipy yüklü değil: pip install sounddevice scipy", None
    except Exception as e:
        return False, f"Mikrofon hatası: {e}", None


# ─────────────────────────────────────────
# Oturumu Kapatma (Logout)
# ─────────────────────────────────────────

def logout_user() -> tuple[bool, str]:
    """Kullanıcının aktif oturumunu kapatır."""
    try:
        if SYSTEM == "Linux":
            current_user = os.getenv("USER") or os.getenv("LOGNAME") or ""
            logout_commands = [
                ["loginctl", "terminate-user", current_user],
                ["qdbus", "org.kde.ksmserver", "/KSMServer", "logout", "0", "0", "0"],
                ["gnome-session-quit", "--logout", "--no-prompt"],
                ["pkill", "-KILL", "-u", current_user],
            ]
            for cmd in logout_commands:
                if not cmd[-1]:
                    continue
                try:
                    subprocess.run(cmd, check=True, timeout=5)
                    return True, f"Oturum kapatıldı ({cmd[0]})"
                except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                    continue
            return False, "Uyumlu oturum kapatma aracı bulunamadı"

        elif SYSTEM == "Windows":
            subprocess.run(["shutdown", "/l"], check=True)
            return True, "Windows oturumu kapatıldı"

        return False, f"Desteklenmeyen işletim sistemi: {SYSTEM}"
    except Exception as e:
        return False, f"Oturum kapatma hatası: {e}"


# ─────────────────────────────────────────
# Yardımcı: Tüm komutları eşleştiren harita
# ─────────────────────────────────────────

COMMAND_MAP = {
    "shutdown": {
        "func": shutdown,
        "has_file": False,
        "description": "Bilgisayarı kapat",
    },
    "lock": {
        "func": lock_screen,
        "has_file": False,
        "description": "Ekranı kilitle",
    },
    "logout": {
        "func": logout_user,
        "has_file": False,
        "description": "Oturumu kapat",
    },
    "screenshot": {
        "func": take_screenshot,
        "has_file": True,
        "description": "Ekran görüntüsü al",
    },
    "webcam": {
        "func": capture_webcam,
        "has_file": True,
        "description": "Web kamerasından fotoğraf çek",
    },
    "mic_record": {
        "func": record_microphone,
        "has_file": True,
        "description": "Mikrofon kaydı yap",
    },
}
