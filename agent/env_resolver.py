"""
AlertRox — Dinamik Masaüstü Ortamı Çözümleyici (Lazy Desktop Environment Resolver)

Systemd kullanıcı servisi oturum açılmadan önce (linger açıkken) başladığında
WAYLAND_DISPLAY, DISPLAY veya DBUS_SESSION_BUS_ADDRESS ortam değişkenleri henüz
mevcut olmayabilir. Bu modül, kullanıcı masaüstüne giriş yaptığında bu değişkenleri
çalışma zamanında dinamik olarak çözer ve günceller.
"""

import os
import sys
import subprocess
import logging

logger = logging.getLogger("AlertRox.EnvResolver")


def _resolve_from_systemd() -> dict[str, str]:
    """systemctl --user show-environment çıktısını ayrıştırır."""
    env = {}
    try:
        res = subprocess.run(
            ["systemctl", "--user", "show-environment"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if res.returncode == 0:
            for line in res.stdout.splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip()
    except Exception as e:
        logger.debug(f"systemctl --user show-environment hatası: {e}")
    return env


def _resolve_from_proc() -> dict[str, str]:
    """Kullanıcının aktif masaüstü sürecinin (/proc/<pid>/environ) ortamını okur."""
    desktop_procs = ["plasmashell", "kwin_wayland", "gnome-shell", "hyprland", "sway", "waybar"]
    env = {}
    try:
        import psutil
        uid = os.getuid()
        for p in psutil.process_iter(["pid", "name", "uids"]):
            try:
                if p.info["uids"] and p.info["uids"].real == uid:
                    pname = (p.info["name"] or "").lower()
                    if any(dp in pname for dp in desktop_procs):
                        # /proc/<pid>/environ dosyasını oku
                        env_file = f"/proc/{p.info['pid']}/environ"
                        if os.path.exists(env_file):
                            with open(env_file, "rb") as f:
                                data = f.read()
                            entries = data.split(b"\x00")
                            for entry in entries:
                                try:
                                    s = entry.decode("utf-8", errors="ignore")
                                    if "=" in s:
                                        k, v = s.split("=", 1)
                                        if k in (
                                            "WAYLAND_DISPLAY",
                                            "DISPLAY",
                                            "DBUS_SESSION_BUS_ADDRESS",
                                            "XDG_RUNTIME_DIR",
                                            "XDG_CURRENT_DESKTOP",
                                            "XDG_SESSION_TYPE",
                                        ):
                                            env[k] = v
                                except Exception:
                                    pass
                            if "WAYLAND_DISPLAY" in env or "DISPLAY" in env:
                                break
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
    except Exception as e:
        logger.debug(f"/proc environ tarama hatası: {e}")
    return env


def get_desktop_env() -> dict[str, str]:
    """
    Geçerli çalışan masaüstü ortam değişkenlerini döndürür.
    Mevcut os.environ ile birleştirilir.
    """
    env = os.environ.copy()
    if sys.platform != "linux":
        return env

    # Önce systemd user environment'ı dene
    sys_env = _resolve_from_systemd()
    for k in (
        "WAYLAND_DISPLAY",
        "DISPLAY",
        "DBUS_SESSION_BUS_ADDRESS",
        "XDG_RUNTIME_DIR",
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE",
    ):
        if sys_env.get(k):
            env[k] = sys_env[k]

    # Eğer hala WAYLAND_DISPLAY veya DISPLAY yoksa, proc üzerinden ara
    if "WAYLAND_DISPLAY" not in env and "DISPLAY" not in env:
        proc_env = _resolve_from_proc()
        for k, v in proc_env.items():
            env[k] = v

    # Fallback varsayılanları (varsa soketleri kontrol et)
    uid = os.getuid()
    runtime_dir = env.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")
    if os.path.exists(runtime_dir):
        env["XDG_RUNTIME_DIR"] = runtime_dir
        if "DBUS_SESSION_BUS_ADDRESS" not in env:
            bus_sock = os.path.join(runtime_dir, "bus")
            if os.path.exists(bus_sock):
                env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus_sock}"

        if "WAYLAND_DISPLAY" not in env:
            wayland_sock = os.path.join(runtime_dir, "wayland-0")
            if os.path.exists(wayland_sock):
                env["WAYLAND_DISPLAY"] = "wayland-0"

    if "DISPLAY" not in env and os.path.exists("/tmp/.X11-unix/X0"):
        env["DISPLAY"] = ":0"

    return env


def apply_desktop_env() -> dict[str, str]:
    """Masaüstü ortam değişkenlerini os.environ içine yansıtır."""
    resolved = get_desktop_env()
    for k in (
        "WAYLAND_DISPLAY",
        "DISPLAY",
        "DBUS_SESSION_BUS_ADDRESS",
        "XDG_RUNTIME_DIR",
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE",
    ):
        if k in resolved:
            os.environ[k] = resolved[k]
    return resolved
