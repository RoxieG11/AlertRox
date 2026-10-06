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
# Ses & Medya Kontrolü
# ─────────────────────────────────────────

def set_volume(level: int) -> tuple[bool, str]:
    """Ses seviyesini 0-100 arasında ayarlar."""
    try:
        level = max(0, min(100, int(level)))
        if SYSTEM == "Linux":
            subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{level}%"], check=True)
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"], check=False)
        elif SYSTEM == "Windows":
            # NirCmd veya powershell ile ses ayarı
            ps_cmd = f"$obj = New-Object -ComObject WScript.Shell; 1..50 | % {{ $obj.SendKeys([char]174) }}; 1..{level // 2} | % {{ $obj.SendKeys([char]175) }}"
            subprocess.run(["powershell", "-WindowStyle", "Hidden", "-Command", ps_cmd], check=False)
        return True, f"Ses seviyesi %{level} yapıldı"
    except Exception as e:
        return False, f"Ses ayarlanamadı: {e}"


def toggle_mute() -> tuple[bool, str]:
    """Sesi sessize alır ya da sesi açar."""
    try:
        if SYSTEM == "Linux":
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"], check=True)
        elif SYSTEM == "Windows":
            ps_cmd = "$obj = New-Object -ComObject WScript.Shell; $obj.SendKeys([char]173)"
            subprocess.run(["powershell", "-WindowStyle", "Hidden", "-Command", ps_cmd], check=False)
        return True, "Sessiz durumu değiştirildi"
    except Exception as e:
        return False, f"Mute hatası: {e}"


def get_volume_status() -> dict:
    """Mevcut ses seviyesini ve sessiz durumunu döndürür."""
    vol = 50
    muted = False
    try:
        if SYSTEM == "Linux":
            import re
            out = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], text=True)
            m = re.search(r"(\d+)%", out)
            if m:
                vol = int(m.group(1))
            mute_out = subprocess.check_output(["pactl", "get-sink-mute", "@DEFAULT_SINK@"], text=True)
            muted = "yes" in mute_out.lower()
    except Exception:
        pass
    return {"volume": vol, "muted": muted}


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
    try:
        if SYSTEM == "Linux":
            # KDE Plasma qdbus6 ve standart dbus-send ile tüm MPRIS oynatıcılara sinyal gönder
            found = 0
            for bus_cmd in ["qdbus6", "qdbus"]:
                try:
                    res = subprocess.run([bus_cmd], capture_output=True, text=True, timeout=1)
                    if res.returncode == 0:
                        players = [line.strip() for line in res.stdout.splitlines() if line.strip().startswith("org.mpris.MediaPlayer2")]
                        for p in players:
                            subprocess.run([bus_cmd, p, "/org/mpris/MediaPlayer2", f"org.mpris.MediaPlayer2.Player.{mpris_act}"], timeout=1)
                            found += 1
                        break
                except Exception:
                    pass

            if found == 0:
                # Standart klavye tuşu simülasyonu (XF86AudioPlay, Next, Prev)
                key_map = {
                    "play_pause": "XF86AudioPlay",
                    "next": "XF86AudioNext",
                    "previous": "XF86AudioPrev",
                    "stop": "XF86AudioStop",
                }
                k = key_map.get(action, "XF86AudioPlay")
                try:
                    subprocess.run(["xdotool", "key", k], timeout=1)
                except Exception:
                    pass

            return True, f"Medya kontrolü ({action}) uygulandı"
        elif SYSTEM == "Windows":
            key_codes = {
                "play_pause": 179,
                "next": 176,
                "previous": 177,
                "stop": 178,
            }
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
    """PC panosuna metin yazar (KDE Klipper, Wayland wl-copy, xclip, Windows)."""
    if not text:
        return False, "Boş metin"
    try:
        # 1. KDE Klipper (Wayland & X11)
        for cmd in [["qdbus6", "org.kde.klipper", "/klipper", "setClipboardContents", text],
                    ["qdbus", "org.kde.klipper", "/klipper", "setClipboardContents", text]]:
            try:
                res = subprocess.run(cmd, timeout=2, capture_output=True)
                if res.returncode == 0:
                    return True, "Metin PC panosuna kopyalandı"
            except Exception:
                pass

        # 2. wl-copy (Wayland)
        try:
            res = subprocess.run(["wl-copy"], input=text.encode("utf-8"), timeout=2, capture_output=True)
            if res.returncode == 0:
                return True, "Metin Wayland panosuna kopyalandı"
        except Exception:
            pass

        # 3. xclip (X11)
        try:
            res = subprocess.run(["xclip", "-selection", "clipboard"], input=text.encode("utf-8"), timeout=2, capture_output=True)
            if res.returncode == 0:
                return True, "Metin X11 panosuna kopyalandı"
        except Exception:
            pass

        # 4. Windows
        if SYSTEM == "Windows":
            res = subprocess.run(["clip"], input=text.encode("utf-16"), timeout=2, capture_output=True)
            if res.returncode == 0:
                return True, "Metin Windows panosuna kopyalandı"

        return False, "Pano aracı bulunamadı"
    except Exception as e:
        return False, f"Pano yazma hatası: {e}"


def get_clipboard() -> str:
    """PC panosundaki metni okur."""
    try:
        # 1. KDE Klipper
        for cmd in [["qdbus6", "org.kde.klipper", "/klipper", "getClipboardContents"],
                    ["qdbus", "org.kde.klipper", "/klipper", "getClipboardContents"],
                    ["wl-paste"],
                    ["xclip", "-selection", "clipboard", "-o"]]:
            try:
                res = subprocess.run(cmd, timeout=2, capture_output=True, text=True)
                if res.returncode == 0 and res.stdout:
                    return res.stdout.strip()
            except Exception:
                pass
        return ""
    except Exception:
        return ""


# ─────────────────────────────────────────
# Uygulama Başlatma & Çalışan Süreçleri Yönetme
# ─────────────────────────────────────────

def get_installed_applications() -> list:
    """PC'de yüklü olan masaüstü uygulamalarını tarar ve listeler."""
    import glob
    apps = []
    seen = set()

    if SYSTEM == "Linux":
        dirs = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]
        for d in dirs:
            for fpath in glob.glob(os.path.join(d, "*.desktop")):
                try:
                    with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                        name, exec_cmd, icon, nodisplay, typ = None, None, None, False, "Application"
                        for line in f:
                            line = line.strip()
                            if line.startswith("Name=") and not name:
                                name = line[5:]
                            elif line.startswith("Exec=") and not exec_cmd:
                                parts = [p for p in line[5:].split() if not p.startswith("%")]
                                exec_cmd = " ".join(parts)
                            elif line.startswith("Icon=") and not icon:
                                icon = line[5:]
                            elif line == "NoDisplay=true":
                                nodisplay = True
                            elif line == "Type=Link":
                                typ = "Link"
                        if name and exec_cmd and not nodisplay and typ == "Application" and name not in seen:
                            seen.add(name)
                            apps.append({"name": name, "exec": exec_cmd, "icon": icon or "application-x-executable"})
                except Exception:
                    pass
        apps.sort(key=lambda x: x["name"].lower())

    elif SYSTEM == "Windows":
        # Windows Start Menu kısayolları taranabilir
        apps.append({"name": "Hesap Makinesi", "exec": "calc.exe", "icon": "calc"})
        apps.append({"name": "Not Defteri", "exec": "notepad.exe", "icon": "notepad"})
        apps.append({"name": "Dosya Gezgini", "exec": "explorer.exe", "icon": "explorer"})

    return apps


def launch_application(exec_cmd: str) -> tuple[bool, str]:
    """PC'de belirtilen komutla uygulama başlatır."""
    if not exec_cmd:
        return False, "Komut belirtilmedi"
    try:
        # Arka planda bağımsız başlat (detach)
        env = os.environ.copy()
        if "DISPLAY" not in env:
            env["DISPLAY"] = ":0"
        if "WAYLAND_DISPLAY" not in env:
            env["WAYLAND_DISPLAY"] = "wayland-0"
        if "XDG_RUNTIME_DIR" not in env:
            env["XDG_RUNTIME_DIR"] = "/run/user/1000"

        subprocess.Popen(
            exec_cmd,
            shell=True,
            env=env,
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True, f"'{exec_cmd}' başlatıldı"
    except Exception as e:
        return False, f"Uygulama başlatma hatası: {e}"


def get_running_processes() -> list:
    """PC'de kullanıcının açık olan uygulamalarını/süreçlerini listeler."""
    import psutil
    user = os.environ.get("USER", "roxie")
    ignore_names = {
        "systemd", "(sd-pam)", "dbus-broker", "dbus-broker-launch",
        "kwin_wayland", "kwin_wayland_wrapper", "pipewire", "pipewire-pulse",
        "wireplumber", "polkit-kde-authentication-agent-1", "agent",
        "python", "python3", "sh", "bash", "zsh", "fish", "sleep", "cat",
        "ps", "grep", "sed", "awk", "sshd", "login",
    }
    apps = {}
    for p in psutil.process_iter(["pid", "name", "cmdline", "cpu_percent", "memory_percent", "username"]):
        try:
            info = p.info
            pname = info.get("name") or ""
            if SYSTEM == "Linux" and info.get("username") != user:
                continue
            if pname in ignore_names or pname.startswith(("kworker", "ksoftirqd")):
                continue
            cmdline = info.get("cmdline") or []
            if not cmdline:
                continue

            display_name = pname
            if pname in ("electron", "python", "python3", "java", "node") and len(cmdline) > 1:
                display_name = f"{pname} ({os.path.basename(cmdline[1])})"

            key = display_name
            if key not in apps or (info.get("memory_percent") or 0) > apps[key]["mem"]:
                apps[key] = {
                    "pid": info["pid"],
                    "name": display_name,
                    "mem": round(info.get("memory_percent") or 0, 1),
                    "cpu": round(info.get("cpu_percent") or 0, 1),
                }
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    return sorted(apps.values(), key=lambda x: x["mem"], reverse=True)


def kill_process(pid: int) -> tuple[bool, str]:
    """Belirtilen PID'li süreci sonlandırır."""
    import psutil
    try:
        pid = int(pid)
        p = psutil.Process(pid)
        pname = p.name()
        p.terminate()
        try:
            p.wait(timeout=2)
        except psutil.TimeoutExpired:
            p.kill()
        return True, f"'{pname}' (PID: {pid}) sonlandırıldı"
    except psutil.NoSuchProcess:
        return True, "Süreç zaten kapanmış"
    except Exception as e:
        return False, f"Süreç kapatılamadı: {e}"


# ─────────────────────────────────────────
# Yardımcı: Tüm komutları eşleştiren harita
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
    "toggle_mute": {
        "func": toggle_mute,
        "has_file": False,
        "description": "Sessiz durumunu değiştir",
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
    "launch_app": {
        "func": launch_application,
        "has_file": False,
        "description": "Uygulama başlat",
    },
    "kill_process": {
        "func": kill_process,
        "has_file": False,
        "description": "Süreç sonlandır",
    },
}

