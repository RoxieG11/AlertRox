"""
AlertRox — Sistem Komutları (Güvenlik Sertleştirmeli & Dinamik Ortam Destekli)

Bilgisayar üzerinde çalıştırılacak tüm sistem komutları burada tanımlanır.
Linux (KDE Plasma, Wayland, PipeWire/WirePlumber, X11) ve Windows tam uyumludur.
"""

import os
import re
import sys
import glob
import shlex
import shutil
import hashlib
import platform
import subprocess
import tempfile
from datetime import datetime

from agent.env_resolver import get_desktop_env

SYSTEM = platform.system()  # "Linux" veya "Windows"

# Pano sonsuz yankıyı önlemek için son uygulanan metnin SHA-256 özeti
_last_applied_clipboard_hash: str | None = None

# Yüklü masaüstü uygulamaları önbelleği: {app_id: {name, exec, icon, path}}
_installed_apps_cache: dict[str, dict] = {}

# Kapatılması kesinlikle engellenmiş kritik süreçler
PROTECTED_PROCESSES = {
    "systemd", "(sd-pam)", "kwin_wayland", "kwin_wayland_wrapper", "kwin_x11",
    "plasmashell", "pipewire", "pipewire-pulse", "wireplumber",
    "dbus-broker", "dbus-broker-launch", "dbus-daemon",
    "polkit-kde-authentication-agent-1", "polkitd",
    "agent", "python", "python3", "sh", "bash", "zsh", "fish",
    "sshd", "login", "Xwayland", "Xorg", "alertrox",
}


# ─────────────────────────────────────────
# Bilgisayarı Kapatma
# ─────────────────────────────────────────

def shutdown(delay_seconds: int = 60) -> tuple[bool, str]:
    """Bilgisayarı belirtilen saniye sonra kapatır."""
    try:
        delay_seconds = max(5, min(86400, int(delay_seconds)))
        if SYSTEM == "Linux":
            delay_minutes = max(1, delay_seconds // 60)
            subprocess.run(["shutdown", "-h", f"+{delay_minutes}"], check=True)
        elif SYSTEM == "Windows":
            subprocess.run(["shutdown", "/s", "/t", str(delay_seconds)], check=True)
        else:
            return False, f"Desteklenmeyen işletim sistemi: {SYSTEM}"

        return True, f"Bilgisayar {delay_seconds} saniye sonra kapanacak"
    except Exception as e:
        return False, f"Kapatma hatası: {e}"


def shutdown_now() -> tuple[bool, str]:
    """Bilgisayarı derhal kapatır."""
    try:
        if SYSTEM == "Linux":
            try:
                subprocess.run(["systemctl", "poweroff"], check=True)
            except Exception:
                subprocess.run(["shutdown", "-h", "now"], check=True)
        elif SYSTEM == "Windows":
            subprocess.run(["shutdown", "/s", "/t", "0"], check=True)
        return True, "Bilgisayar kapatılıyor"
    except Exception as e:
        return False, f"Kapatma hatası: {e}"


def cancel_shutdown() -> tuple[bool, str]:
    """Zamanlanmış kapatmayı iptal eder."""
    try:
        if SYSTEM == "Linux":
            subprocess.run(["shutdown", "-c"], check=False)
        elif SYSTEM == "Windows":
            subprocess.run(["shutdown", "/a"], check=False)

        return True, "Kapatma iptal edildi"
    except Exception as e:
        return False, f"İptal hatası: {e}"


# ─────────────────────────────────────────
# Ekranı Kilitleme
# ─────────────────────────────────────────

def lock_screen() -> tuple[bool, str]:
    """Ekranı kilitler. Dinamik masaüstü ortamını kullanır."""
    try:
        if SYSTEM == "Linux":
            env = get_desktop_env()
            lock_commands = [
                ["loginctl", "lock-session"],
                ["qdbus6", "org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"],
                ["qdbus", "org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"],
                ["xdg-screensaver", "lock"],
                ["dbus-send", "--type=method_call",
                 "--dest=org.gnome.ScreenSaver",
                 "/org/gnome/ScreenSaver",
                 "org.gnome.ScreenSaver.Lock"],
            ]

            for cmd in lock_commands:
                try:
                    res = subprocess.run(cmd, check=True, capture_output=True, timeout=5, env=env)
                    return True, f"Ekran kilitlendi ({cmd[0]})"
                except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                    continue

            return False, "Uyumlu ekran kilitleme aracı bulunamadı"

        elif SYSTEM == "Windows":
            subprocess.run(["rundll32.exe", "user32.dll,LockWorkStation"], check=True)
        else:
            return False, f"Desteklenmeyen işletim sistemi: {SYSTEM}"

        return True, "Ekran kilitlendi"
    except Exception as e:
        return False, f"Kilitleme hatası: {e}"


# ─────────────────────────────────────────
# Oturumu Kapatma (Logout)
# ─────────────────────────────────────────

def logout_user() -> tuple[bool, str]:
    """Kullanıcı oturumunu kapatır."""
    try:
        if SYSTEM == "Linux":
            env = get_desktop_env()
            for cmd in [
                ["qdbus6", "org.kde.Shutdown", "/Shutdown", "logout"],
                ["qdbus", "org.kde.Shutdown", "/Shutdown", "logout"],
                ["loginctl", "terminate-session", ""],
            ]:
                try:
                    subprocess.run(cmd, timeout=3, check=True, env=env)
                    return True, "Oturum kapatıldı"
                except Exception:
                    pass
            return False, "Oturum kapatma komutu çalıştırılamadı"
        elif SYSTEM == "Windows":
            subprocess.run(["shutdown", "/l"], check=True)
            return True, "Windows oturumu kapatıldı"
        return False, "Desteklenmeyen sistem"
    except Exception as e:
        return False, f"Oturum kapatma hatası: {e}"


# ─────────────────────────────────────────
# Ekran Görüntüsü Alma
# ─────────────────────────────────────────

def take_screenshot() -> tuple[bool, str, str | None]:
    """
    Ekran görüntüsü alır ve geçici dosyaya kaydeder.
    Wayland ve X11 oturumlarında dinamik masaüstü ortamını kullanır.
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_path = os.path.join(tempfile.gettempdir(), f"alertrox_ss_{timestamp}.png")
    env = get_desktop_env()

    if SYSTEM == "Linux":
        linux_screenshot_tools = [
            ["spectacle", "-b", "-n", "-o", file_path],  # KDE Plasma
            ["grim", file_path],                         # Wayland genel
            ["gnome-screenshot", "-f", file_path],       # GNOME
            ["scrot", file_path],                        # X11
            ["import", "-window", "root", file_path],    # ImageMagick
        ]

        for cmd in linux_screenshot_tools:
            try:
                subprocess.run(cmd, check=True, capture_output=True, timeout=6, env=env)
                if os.path.exists(file_path) and os.path.getsize(file_path) > 1000:
                    return True, f"Ekran görüntüsü alındı ({cmd[0]})", file_path
            except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                continue

    # Windows veya mss fallback
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
    """Web kamerasından fotoğraf çeker."""
    try:
        import cv2

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_path = os.path.join(tempfile.gettempdir(), f"alertrox_cam_{timestamp}.jpg")

        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            return False, "Web kamerası bulunamadı veya kullanımda", None

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
    """Mikrofondan ses kaydeder."""
    try:
        import sounddevice as sd
        from scipy.io import wavfile
        import numpy as np

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_path = os.path.join(tempfile.gettempdir(), f"alertrox_mic_{timestamp}.wav")

        sample_rate = 44100
        duration_seconds = max(1, min(120, int(duration_seconds)))

        print(f"[AlertRox] Mikrofon kaydı başladı ({duration_seconds} saniye)...")
        recording = sd.rec(
            int(duration_seconds * sample_rate),
            samplerate=sample_rate,
            channels=1,
            dtype=np.int16,
        )
        sd.wait()

        wavfile.write(file_path, sample_rate, recording)
        return True, f"{duration_seconds} saniye ses kaydedildi", file_path
    except ImportError:
        return False, "sounddevice veya scipy yüklü değil", None
    except Exception as e:
        return False, f"Mikrofon hatası: {e}", None


# ─────────────────────────────────────────
# Ses Kontrolü (PipeWire wpctl / pactl / Windows)
# ─────────────────────────────────────────

def set_volume(level: int) -> tuple[bool, str]:
    """
    Ses seviyesini %0 ile %100 arasında ayarlar.
    Linux'ta WirePlumber/PipeWire (wpctl), ardından pactl ve amixer önceliği uygular.
    """
    try:
        level = max(0, min(100, int(level)))
        env = get_desktop_env()

        if SYSTEM == "Linux":
            # 1. wpctl (PipeWire / WirePlumber - CachyOS/Fedora/Arch varsayılanı)
            if shutil.which("wpctl"):
                try:
                    subprocess.run(
                        ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{level}%"],
                        check=True,
                        capture_output=True,
                        env=env,
                    )
                    if level > 0:
                        subprocess.run(
                            ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"],
                            check=False,
                            capture_output=True,
                            env=env,
                        )
                    return True, f"Ses seviyesi %{level} yapıldı (wpctl)"
                except Exception:
                    pass

            # 2. pactl (PulseAudio)
            if shutil.which("pactl"):
                try:
                    subprocess.run(
                        ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{level}%"],
                        check=True,
                        capture_output=True,
                        env=env,
                    )
                    if level > 0:
                        subprocess.run(
                            ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"],
                            check=False,
                            capture_output=True,
                            env=env,
                        )
                    return True, f"Ses seviyesi %{level} yapıldı (pactl)"
                except Exception:
                    pass

            # 3. amixer (ALSA)
            if shutil.which("amixer"):
                try:
                    subprocess.run(
                        ["amixer", "-D", "pulse", "sset", "Master", f"{level}%"],
                        check=True,
                        capture_output=True,
                        env=env,
                    )
                    return True, f"Ses seviyesi %{level} yapıldı (amixer)"
                except Exception:
                    pass

            return False, "Uyumlu ses kontrol aracı bulunamadı (wpctl, pactl veya amixer)"

        elif SYSTEM == "Windows":
            ps_cmd = f"$obj = New-Object -ComObject WScript.Shell; 1..50 | % {{ $obj.SendKeys([char]174) }}; 1..{level // 2} | % {{ $obj.SendKeys([char]175) }}"
            subprocess.run(["powershell", "-WindowStyle", "Hidden", "-Command", ps_cmd], check=False)
            return True, f"Ses seviyesi %{level} yapıldı"

        return False, "Desteklenmeyen sistem"
    except Exception as e:
        return False, f"Ses ayarlanamadı: {e}"


def volume_step(delta: int = 5) -> tuple[bool, str]:
    """Mevcut ses seviyesini delta kadar artırır veya azaltır."""
    curr = get_volume_status()
    new_vol = max(0, min(100, curr["volume"] + delta))
    return set_volume(new_vol)


def toggle_mute() -> tuple[bool, str]:
    """Sesi sessize alır ya da sesi açar."""
    try:
        env = get_desktop_env()
        if SYSTEM == "Linux":
            # 1. wpctl
            if shutil.which("wpctl"):
                try:
                    subprocess.run(
                        ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"],
                        check=True,
                        capture_output=True,
                        env=env,
                    )
                    return True, "Sessiz durumu değiştirildi (wpctl)"
                except Exception:
                    pass

            # 2. pactl
            if shutil.which("pactl"):
                try:
                    subprocess.run(
                        ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"],
                        check=True,
                        capture_output=True,
                        env=env,
                    )
                    return True, "Sessiz durumu değiştirildi (pactl)"
                except Exception:
                    pass

            return False, "Mute aracı bulunamadı"

        elif SYSTEM == "Windows":
            ps_cmd = "$obj = New-Object -ComObject WScript.Shell; $obj.SendKeys([char]173)"
            subprocess.run(["powershell", "-WindowStyle", "Hidden", "-Command", ps_cmd], check=False)
            return True, "Sessiz durumu değiştirildi"

        return False, "Desteklenmeyen sistem"
    except Exception as e:
        return False, f"Mute hatası: {e}"


def set_mute(muted: bool) -> tuple[bool, str]:
    """Sessiz durumunu açık veya kapalı olarak kesin ayarlar."""
    try:
        env = get_desktop_env()
        val_str = "1" if muted else "0"
        if SYSTEM == "Linux":
            if shutil.which("wpctl"):
                subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", val_str], check=True, env=env)
                return True, f"Sessiz durumu: {muted}"
            if shutil.which("pactl"):
                subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", val_str], check=True, env=env)
                return True, f"Sessiz durumu: {muted}"
        return toggle_mute()
    except Exception as e:
        return False, f"Set mute hatası: {e}"


def get_volume_status() -> dict:
    """Mevcut ses seviyesini, sessiz durumunu ve kullanılan arka ucu döndürür."""
    vol = 50
    muted = False
    backend = "none"
    env = get_desktop_env()

    if SYSTEM == "Linux":
        # 1. wpctl
        if shutil.which("wpctl"):
            try:
                out = subprocess.check_output(
                    ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
                    text=True,
                    env=env,
                    timeout=2,
                ).strip()
                m = re.search(r"Volume:\s+([0-9.]+)", out)
                if m:
                    vol = int(round(float(m.group(1)) * 100))
                    vol = min(100, vol)
                    muted = "[MUTED]" in out
                    backend = "wpctl"
                    return {"volume": vol, "muted": muted, "backend": backend}
            except Exception:
                pass

        # 2. pactl
        if shutil.which("pactl"):
            try:
                out = subprocess.check_output(
                    ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                    text=True,
                    env=env,
                    timeout=2,
                )
                m = re.search(r"(\d+)%", out)
                if m:
                    vol = min(100, int(m.group(1)))
                mute_out = subprocess.check_output(
                    ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
                    text=True,
                    env=env,
                    timeout=2,
                )
                muted = "yes" in mute_out.lower()
                backend = "pactl"
                return {"volume": vol, "muted": muted, "backend": backend}
            except Exception:
                pass

    return {"volume": vol, "muted": muted, "backend": backend}


# ─────────────────────────────────────────
# Medya Oynatıcı Kontrolü (MPRIS / DBus)
# ─────────────────────────────────────────

def control_media(action: str = "play_pause") -> tuple[bool, str]:
    """
    Medya oynatıcısını kontrol eder.
    action: 'play_pause' | 'next' | 'previous' | 'stop'
    """
    act_map = {
        "play_pause": "PlayPause",
        "next": "Next",
        "previous": "Previous",
        "stop": "Stop",
    }
    mpris_act = act_map.get(action, "PlayPause")
    env = get_desktop_env()

    try:
        if SYSTEM == "Linux":
            found = 0
            for bus_cmd in ["qdbus6", "qdbus"]:
                if shutil.which(bus_cmd):
                    try:
                        res = subprocess.run([bus_cmd], capture_output=True, text=True, timeout=1, env=env)
                        if res.returncode == 0:
                            players = [
                                line.strip()
                                for line in res.stdout.splitlines()
                                if line.strip().startswith("org.mpris.MediaPlayer2")
                            ]
                            for p in players:
                                subprocess.run(
                                    [bus_cmd, p, "/org/mpris/MediaPlayer2", f"org.mpris.MediaPlayer2.Player.{mpris_act}"],
                                    timeout=1,
                                    env=env,
                                )
                                found += 1
                            if found > 0:
                                break
                    except Exception:
                        pass

            if found == 0 and shutil.which("playerctl"):
                p_act = "play-pause" if action == "play_pause" else action
                subprocess.run(["playerctl", p_act], timeout=1, env=env)
                found += 1

            return True, f"Medya kontrolü ({action}) uygulandı"

        elif SYSTEM == "Windows":
            key_codes = {"play_pause": 179, "next": 176, "previous": 177, "stop": 178}
            code = key_codes.get(action, 179)
            ps_cmd = f"$obj = New-Object -ComObject WScript.Shell; $obj.SendKeys([char]{code})"
            subprocess.run(["powershell", "-WindowStyle", "Hidden", "-Command", ps_cmd], check=False)
            return True, f"Windows medya ({action}) uygulandı"

        return False, "Desteklenmeyen sistem"
    except Exception as e:
        return False, f"Medya kontrol hatası: {e}"


# ─────────────────────────────────────────
# Evrensel Pano (Universal Clipboard)
# ─────────────────────────────────────────

def set_clipboard(text: str) -> tuple[bool, str]:
    """PC panosuna metin yazar. SHA-256 özeti kaydedilerek yankı engellenir."""
    global _last_applied_clipboard_hash
    if not text:
        return False, "Boş metin"

    if len(text) > 102400:  # 100 KB sınır
        return False, "Metin boyutu 100 KB sınırını aşıyor"

    # Hash kaydet
    text_hash = hashlib.sha256(text.encode("utf-8")).hexdigest()
    _last_applied_clipboard_hash = text_hash

    env = get_desktop_env()

    try:
        # 1. KDE Klipper (Plasma 6 / Wayland / X11)
        for bus_cmd in ["qdbus6", "qdbus"]:
            if shutil.which(bus_cmd):
                try:
                    res = subprocess.run(
                        [bus_cmd, "org.kde.klipper", "/klipper", "setClipboardContents", text],
                        timeout=2,
                        capture_output=True,
                        env=env,
                    )
                    if res.returncode == 0:
                        return True, "Metin KDE Klipper panosuna kopyalandı"
                except Exception:
                    pass

        # 2. wl-copy (Wayland)
        if shutil.which("wl-copy"):
            try:
                res = subprocess.run(
                    ["wl-copy"],
                    input=text.encode("utf-8"),
                    timeout=2,
                    capture_output=True,
                    env=env,
                )
                if res.returncode == 0:
                    return True, "Metin Wayland panosuna kopyalandı"
            except Exception:
                pass

        # 3. xclip (X11)
        if shutil.which("xclip"):
            try:
                res = subprocess.run(
                    ["xclip", "-selection", "clipboard"],
                    input=text.encode("utf-8"),
                    timeout=2,
                    capture_output=True,
                    env=env,
                )
                if res.returncode == 0:
                    return True, "Metin X11 panosuna kopyalandı"
            except Exception:
                pass

        # 4. Windows clip
        if SYSTEM == "Windows":
            res = subprocess.run(["clip"], input=text.encode("utf-16"), timeout=2, capture_output=True)
            if res.returncode == 0:
                return True, "Metin Windows panosuna kopyalandı"

        return False, "Pano aracı bulunamadı (wl-copy, xclip veya KDE Klipper)"
    except Exception as e:
        return False, f"Pano yazma hatası: {e}"


def get_clipboard() -> str:
    """PC panosundaki metni okur."""
    env = get_desktop_env()
    try:
        # 1. KDE Klipper (Wayland & X11)
        for bus_cmd in ["qdbus6", "qdbus"]:
            if shutil.which(bus_cmd):
                try:
                    res = subprocess.run(
                        [bus_cmd, "org.kde.klipper", "/klipper", "getClipboardContents"],
                        timeout=2,
                        capture_output=True,
                        text=True,
                        env=env,
                    )
                    if res.returncode == 0 and res.stdout:
                        return res.stdout.strip()
                except Exception:
                    pass

        # 2. wl-paste (Wayland)
        if shutil.which("wl-paste"):
            try:
                res = subprocess.run(["wl-paste", "--no-newline"], timeout=2, capture_output=True, text=True, env=env)
                if res.returncode == 0 and res.stdout:
                    return res.stdout.strip()
            except Exception:
                pass

        # 3. xclip (X11)
        if shutil.which("xclip"):
            try:
                res = subprocess.run(
                    ["xclip", "-selection", "clipboard", "-o"],
                    timeout=2,
                    capture_output=True,
                    text=True,
                    env=env,
                )
                if res.returncode == 0 and res.stdout:
                    return res.stdout.strip()
            except Exception:
                pass

        # 4. Windows
        if SYSTEM == "Windows":
            res = subprocess.run(["powershell", "-Command", "Get-Clipboard"], timeout=2, capture_output=True, text=True)
            if res.returncode == 0 and res.stdout:
                return res.stdout.strip()

        return ""
    except Exception:
        return ""


# ─────────────────────────────────────────
# Uygulama Yönetimi (Yüklü & Açık Uygulamalar)
# ─────────────────────────────────────────

def get_installed_applications() -> list[dict]:
    """PC'de yüklü olan tüm masaüstü uygulamalarını tarar ve önbelleğe alır."""
    global _installed_apps_cache
    apps = []
    seen_ids = set()

    if SYSTEM == "Linux":
        search_dirs = [
            "/usr/share/applications",
            os.path.expanduser("~/.local/share/applications"),
            "/var/lib/flatpak/exports/share/applications",
            os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
            "/var/lib/snapd/desktop/applications",
            "/usr/local/share/applications",
        ]

        for d in search_dirs:
            if not os.path.isdir(d):
                continue
            for fpath in glob.glob(os.path.join(d, "*.desktop")):
                app_id = os.path.basename(fpath)
                if app_id in seen_ids:
                    continue

                try:
                    with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                        name = None
                        name_tr = None
                        exec_cmd = None
                        icon = None
                        nodisplay = False
                        hidden = False
                        typ = "Application"

                        for line in f:
                            line = line.strip()
                            if line.startswith("Name=") and not name:
                                name = line[5:].strip()
                            elif line.startswith("Name[tr]=") and not name_tr:
                                name_tr = line[9:].strip()
                            elif line.startswith("Exec=") and not exec_cmd:
                                exec_cmd = line[5:].strip()
                            elif line.startswith("Icon=") and not icon:
                                icon = line[5:].strip()
                            elif line == "NoDisplay=true":
                                nodisplay = True
                            elif line == "Hidden=true":
                                hidden = True
                            elif line.startswith("Type="):
                                typ = line[5:].strip()

                        if (
                            (name or name_tr)
                            and exec_cmd
                            and not nodisplay
                            and not hidden
                            and typ == "Application"
                        ):
                            display_name = name_tr if name_tr else name
                            item = {
                                "id": app_id,
                                "name": display_name,
                                "exec": exec_cmd,
                                "icon": icon or "application-x-executable",
                                "path": fpath,
                            }
                            seen_ids.add(app_id)
                            apps.append(item)
                            _installed_apps_cache[app_id] = item
                except Exception:
                    pass

        apps.sort(key=lambda x: x["name"].lower())

    elif SYSTEM == "Windows":
        apps.append({"id": "calc.exe", "name": "Hesap Makinesi", "exec": "calc.exe", "icon": "calc"})
        apps.append({"id": "notepad.exe", "name": "Not Defteri", "exec": "notepad.exe", "icon": "notepad"})
        apps.append({"id": "explorer.exe", "name": "Dosya Gezgini", "exec": "explorer.exe", "icon": "explorer"})
        for a in apps:
            _installed_apps_cache[a["id"]] = a

    return apps


def launch_application(app_id_or_cmd: str) -> tuple[bool, str]:
    """
    Belirtilen uygulamayı güvenli bir şekilde başlatır.
    DB'den gelen metin asla raw shell'e verilmez.
    """
    global _installed_apps_cache
    if not app_id_or_cmd:
        return False, "Uygulama kimliği belirtilmedi"

    if not _installed_apps_cache:
        get_installed_applications()

    env = get_desktop_env()

    # 1. Önbellekte app_id (örn: 'firefox.desktop') ile ara
    app_info = _installed_apps_cache.get(app_id_or_cmd)
    if not app_info:
        # İsimle ara
        for item in _installed_apps_cache.values():
            if item["name"].lower() == app_id_or_cmd.lower() or item["id"].lower() == app_id_or_cmd.lower():
                app_info = item
                break

    if SYSTEM == "Linux":
        if app_info:
            desktop_id = app_info["id"]
            # gtk-launch ile başlatmayı dene
            if shutil.which("gtk-launch"):
                try:
                    clean_id = desktop_id[:-8] if desktop_id.endswith(".desktop") else desktop_id
                    subprocess.Popen(
                        ["gtk-launch", clean_id],
                        env=env,
                        start_new_session=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return True, f"'{app_info['name']}' başlatıldı (gtk-launch)"
                except Exception:
                    pass

            # gio launch ile başlatmayı dene
            if shutil.which("gio") and app_info.get("path"):
                try:
                    subprocess.Popen(
                        ["gio", "launch", app_info["path"]],
                        env=env,
                        start_new_session=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return True, f"'{app_info['name']}' başlatıldı (gio launch)"
                except Exception:
                    pass

            # Exec komutunu shlex ile ayrıştırıp parametre kodlarını temizle
            raw_exec = app_info["exec"]
            try:
                parts = shlex.split(raw_exec)
                clean_parts = [
                    p for p in parts
                    if not p.startswith(("%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m"))
                ]
                if clean_parts:
                    subprocess.Popen(
                        clean_parts,
                        shell=False,
                        env=env,
                        start_new_session=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return True, f"'{app_info['name']}' başlatıldı"
            except Exception as e:
                return False, f"Uygulama başlatma hatası: {e}"

        return False, f"Uygulama bulunamadı veya yetkisiz: {app_id_or_cmd}"

    elif SYSTEM == "Windows":
        try:
            target = app_info["exec"] if app_info else app_id_or_cmd
            os.startfile(target)
            return True, f"'{target}' başlatıldı"
        except Exception as e:
            return False, f"Windows uygulama başlatma hatası: {e}"

    return False, "Desteklenmeyen sistem"


IGNORED_PROCESS_NAMES = {
    # Tarayıcı yardımcı ve kod çözücü iş parçacıkları
    "isolated web co", "isolated web content", "rdd process", "webextensions",
    "privileged cont", "socket process", "web content", "utility", "gpu-process",
    "crashpad_handler", "firefox-bin",
    # Geliştirme, dil sunucuları ve runtime arka plan süreçleri
    "language_server", "dart", "dartaotruntime", "gradledaemon",
    # Masaüstü ortamı arka plan servisleri
    "baloo_file", "baloorunner", "krunner", "at-spi-bus-launcher",
    "at-spi2-registryd", "dconf-service", "gvfsd", "gvfsd-fuse", "gvfs-udisks2-vo",
    "agent", "alertrox", "systemd", "dbus-daemon", "pipewire", "pipewire-pulse",
    "wireplumber", "pulseaudio", "xwayland",
}


def get_running_processes() -> list[dict]:
    """
    Kullanıcının çalışan açık masaüstü GUI uygulamalarını listeler.
    Tarayıcı iş parçacıklarını, sistem/arka plan servislerini filtreler.
    Java/Python gibi runtime uygulamalarını doğru desktop dosyalarıyla eşleştirir.
    """
    import psutil

    if not _installed_apps_cache:
        get_installed_applications()

    user = os.environ.get("USER", "roxie")
    apps: dict[str, dict] = {}

    for p in psutil.process_iter(["pid", "name", "cmdline", "cpu_percent", "memory_percent", "username"]):
        try:
            info = p.info
            pname = (info.get("name") or "").lower()
            if SYSTEM == "Linux" and info.get("username") != user:
                continue

            if pname in PROTECTED_PROCESSES or pname.startswith(("kworker", "ksoftirqd")):
                continue

            cmdline = info.get("cmdline") or []
            if not cmdline:
                continue

            cmdline_str = " ".join(cmdline).lower()

            # Yardımcı / iç iş parçacıklarını filtrele
            if any(ign in pname for ign in IGNORED_PROCESS_NAMES) or any(ign in cmdline_str for ign in IGNORED_PROCESS_NAMES):
                continue

            # Yüklü desktop uygulamalarıyla eşleştirmeye çalış
            matched_app = None
            for a in _installed_apps_cache.values():
                exec_cmd = a.get("exec", "")
                if not exec_cmd:
                    continue
                exec_first = exec_cmd.split()[0].lower()
                exec_base = os.path.basename(exec_first)

                # Genel runtime'lar (java, python, node, electron, bash, sh, wine) için özel kontrol:
                # 'java' == 'java' kontrolü GradleDaemon veya diğer java süreçlerini TLauncher yapıyordu!
                if exec_base in ("java", "python", "python3", "node", "electron", "bash", "sh", "wine"):
                    app_id_clean = a.get("id", "").replace(".desktop", "").lower()
                    desktop_exec_args = [os.path.basename(arg).lower() for arg in exec_cmd.split()[1:] if not arg.startswith("%")]

                    matched = False
                    for arg in desktop_exec_args:
                        if arg and arg in cmdline_str:
                            matched = True
                            break
                    if not matched and app_id_clean and app_id_clean in cmdline_str:
                        matched = True

                    if matched:
                        matched_app = a
                        break
                else:
                    if pname == exec_base or (cmdline and os.path.basename(cmdline[0]).lower() == exec_base):
                        matched_app = a
                        break

            # Eğer eşleşen masaüstü uygulaması yoksa ve süreç sadece bir runtime (java, python, bash, node vb.) ise atla
            if not matched_app and pname in ("java", "python", "python3", "node", "electron", "bash", "sh", "wine", "zsh"):
                continue

            display_name = matched_app["name"] if matched_app else info["name"]
            app_id = matched_app["id"] if matched_app else pname

            key = display_name
            mem_val = round(info.get("memory_percent") or 0.0, 1)
            cpu_val = round(info.get("cpu_percent") or 0.0, 1)

            if key not in apps or mem_val > apps[key]["mem"]:
                apps[key] = {
                    "id": app_id,
                    "pid": info["pid"],
                    "name": display_name,
                    "mem": mem_val,
                    "cpu": cpu_val,
                    "icon": matched_app["icon"] if matched_app else "application-x-executable",
                }
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    return sorted(apps.values(), key=lambda x: x["mem"], reverse=True)


def close_application(app_id_or_pid) -> tuple[bool, str]:
    """
    Uygulamayı ve tüm alt süreçlerini (çocuk süreçler) nazikçe (SIGTERM),
    gerekirse zorla (SIGKILL) kapatır. Korumalı süreçleri kesinlikle kapatmaz.
    """
    import psutil

    target_pids = []
    user = os.environ.get("USER", "roxie")

    try:
        pid_int = int(app_id_or_pid)
        target_pids.append(pid_int)
    except (ValueError, TypeError):
        app_id_str = str(app_id_or_pid).lower()
        for p in psutil.process_iter(["pid", "name", "cmdline", "username"]):
            try:
                if SYSTEM == "Linux" and p.info.get("username") != user:
                    continue
                pname = (p.info.get("name") or "").lower()
                cmdline = " ".join(p.info.get("cmdline") or []).lower()
                if pname in PROTECTED_PROCESSES:
                    continue
                if app_id_str in pname or app_id_str.replace(".desktop", "") in pname or app_id_str in cmdline:
                    target_pids.append(p.info["pid"])
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

    if not target_pids:
        return False, f"Kapatılacak süreç bulunamadı: {app_id_or_pid}"

    closed_names = []
    for pid in target_pids:
        try:
            p = psutil.Process(pid)
            pname = p.name()
            if pname.lower() in PROTECTED_PROCESSES:
                print(f"[AlertRox Güvenlik] Korumalı süreç kapatılamaz: {pname} (PID: {pid})")
                continue

            # Alt süreçleri topla ve önce onları nazikçe sonlandır
            children = p.children(recursive=True)
            for c in children:
                try:
                    c.terminate()
                except Exception:
                    pass

            p.terminate()

            # Süreçlerin bitmesini bekle
            gone, alive = psutil.wait_procs(children + [p], timeout=2)
            for a in alive:
                try:
                    a.kill()
                except Exception:
                    pass

            closed_names.append(f"{pname} (PID {pid})")
        except psutil.NoSuchProcess:
            continue
        except Exception as e:
            return False, f"Süreç sonlandırma hatası: {e}"

    if closed_names:
        return True, f"Kapatıldı: {', '.join(closed_names)}"
    return False, "Süreç zaten kapanmış veya kapatılamadı"


def kill_process(pid: int) -> tuple[bool, str]:
    """Belirtilen PID'li süreci sonlandırır."""
    return close_application(pid)


# ─────────────────────────────────────────
# Komut Eşleme Haritası
# ─────────────────────────────────────────

COMMAND_MAP = {
    "shutdown": {
        "func": shutdown,
        "has_file": False,
        "description": "Bilgisayarı kapat",
    },
    "cancel_shutdown": {
        "func": cancel_shutdown,
        "has_file": False,
        "description": "Kapatmayı iptal et",
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
    "set_volume": {
        "func": set_volume,
        "has_file": False,
        "description": "Ses seviyesini ayarla",
    },
    "volume_step": {
        "func": volume_step,
        "has_file": False,
        "description": "Ses adımını ayarla",
    },
    "toggle_mute": {
        "func": toggle_mute,
        "has_file": False,
        "description": "Sessiz durumunu değiştir",
    },
    "set_mute": {
        "func": set_mute,
        "has_file": False,
        "description": "Sessiz durumunu ayarla",
    },
    "get_volume": {
        "func": get_volume_status,
        "has_file": False,
        "description": "Ses seviyesini sorgula",
    },
    "media_control": {
        "func": control_media,
        "has_file": False,
        "description": "Medya oynatıcısını kontrol et",
    },
    "set_clipboard": {
        "func": set_clipboard,
        "has_file": False,
        "description": "Pano içeriğini ayarla",
    },
    "get_clipboard": {
        "func": get_clipboard,
        "has_file": False,
        "description": "Pano içeriğini al",
    },
    "launch_app": {
        "func": launch_application,
        "has_file": False,
        "description": "Uygulama başlat",
    },
    "close_app": {
        "func": close_application,
        "has_file": False,
        "description": "Uygulama kapat",
    },
    "kill_process": {
        "func": kill_process,
        "has_file": False,
        "description": "Süreç sonlandır",
    },
    "get_installed_apps": {
        "func": get_installed_applications,
        "has_file": False,
        "description": "Yüklü uygulamaları listele",
    },
    "get_running_apps": {
        "func": get_running_processes,
        "has_file": False,
        "description": "Çalışan uygulamaları listele",
    },
}
