"""
AlertRox — Sistem Teşhis & Kendi Kendine Test Scripti (Self-Test)

Kullanım:
    python -m agent.selftest
"""

import os
import sys
import shutil
import platform
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agent.env_resolver import apply_desktop_env, get_desktop_env


def run():
    print("=" * 60)
    print("  🔍 AlertRox Sistem Teşhisi ve Sağlık Denetimi (Self-Test)")
    print("=" * 60)

    # 1. Ortam Çözümlemesi
    env = apply_desktop_env()
    os_name = platform.system()
    print(f"\n[1] Sistem Bilgisi:")
    print(f"  • İşletim Sistemi : {os_name} ({platform.release()})")
    print(f"  • Kullanıcı       : {env.get('USER', os.environ.get('USER'))}")
    print(f"  • Masaüstü        : {env.get('XDG_CURRENT_DESKTOP', 'Bilinmiyor')}")
    print(f"  • Oturum Türü     : {env.get('XDG_SESSION_TYPE', 'Bilinmiyor')}")
    print(f"  • Wayland Display : {env.get('WAYLAND_DISPLAY', 'Yok')}")
    print(f"  • X11 Display     : {env.get('DISPLAY', 'Yok')}")
    print(f"  • D-Bus Soketi    : {env.get('DBUS_SESSION_BUS_ADDRESS', 'Yok')}")

    # 2. Araç Kontrolleri
    print(f"\n[2] Sistem Yardımcı Araçları:")
    tools = {
        "wpctl (PipeWire)": "wpctl",
        "pactl (PulseAudio)": "pactl",
        "qdbus6 (KDE Qt6)": "qdbus6",
        "qdbus (KDE Qt5)": "qdbus",
        "wl-copy (Wayland)": "wl-copy",
        "wl-paste (Wayland)": "wl-paste",
        "xclip (X11)": "xclip",
        "kdotool (KDE Wayland)": "kdotool",
        "notify-send": "notify-send",
        "spectacle (KDE SS)": "spectacle",
        "grim (Wayland SS)": "grim",
        "gtk-launch": "gtk-launch",
        "gio": "gio",
    }

    missing_arch_pkgs = []
    found_tools = {}

    for name, binary in tools.items():
        found = shutil.which(binary) is not None
        found_tools[binary] = found
        status = "✅ Mevcut" if found else "❌ Eksik"
        print(f"  • {name:<22}: {status}")

    if not found_tools.get("wl-copy") or not found_tools.get("wl-paste"):
        missing_arch_pkgs.append("wl-clipboard")
    if not found_tools.get("xclip"):
        missing_arch_pkgs.append("xclip")

    # 3. Ses Kontrol Testi
    print(f"\n[3] Ses Alt Sistemi Testi:")
    from agent.system_actions import get_volume_status
    vol_status = get_volume_status()
    print(f"  • Ses Seviyesi : %{vol_status.get('volume', '?')}")
    print(f"  • Sessiz (Mute): {'Evet' if vol_status.get('muted') else 'Hayır'}")
    if vol_status.get("backend"):
        print(f"  • Ses Arka Ucu : {vol_status.get('backend')}")

    # 4. Pano (Clipboard) Testi
    print(f"\n[4] Pano Testi:")
    from agent.system_actions import get_clipboard
    clip_text = get_clipboard()
    clip_preview = (clip_text[:30] + "...") if len(clip_text) > 30 else clip_text
    print(f"  • Mevcut Pano İçeriği: {repr(clip_preview) if clip_text else '(Boş)'}")

    # 5. Uygulama Listesi Testi
    print(f"\n[5] Uygulama Yönetimi Testi:")
    from agent.system_actions import get_installed_applications, get_running_processes
    installed = get_installed_applications()
    running_apps = get_running_processes()
    print(f"  • Yüklü Masaüstü Uygulamaları : {len(installed)} adet bulundu")
    if installed:
        print(f"    Örnekler: {', '.join(a['name'] for a in installed[:4])}")
    print(f"  • Çalışan Kullanıcı Süreçleri : {len(running_apps)} adet bulundu")
    if running_apps:
        print(f"    Örnekler: {', '.join(a['name'] for a in running_apps[:4])}")

    # 6. Öneriler
    print(f"\n[6] Öneriler & İyileştirmeler:")
    if missing_arch_pkgs:
        print(f"  ⚠️ CachyOS / Arch için önerilen paketler:")
        print(f"     sudo pacman -S {' '.join(missing_arch_pkgs)}")
    else:
        print("  🎉 Tüm kritik yardımcı paketler kurulu!")

    print("=" * 60)


if __name__ == "__main__":
    run()
