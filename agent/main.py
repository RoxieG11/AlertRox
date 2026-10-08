"""
AlertRox — PC Agent Ana Modülü (Güvenlik Sertleştirmeli & Dinamik Masaüstü Destekli)

Bu script bilgisayar açıldığında otomatik olarak çalışır ve:
1. Tek örnek (single-instance) kilidini alarak çift çalışmayı önler
2. Dinamik masaüstü oturumunu (KDE Plasma/Wayland/PipeWire) çözer
3. Supabase'e kimliği doğrulanmış olarak bağlanır
4. "Ben açıldım!" sinyali ve her 10 saniyede bir heartbeat gönderir
5. Telefondan gelen komutları doğrular, 60s zaman aşımını kontrol eder ve çalıştırır
6. Hassas işlemlerde (webcam, mikrofon, ekran) PC ekranında güvenlik bildirimi gösterir
7. Her 60 saniyede bir sağlık denetimi (health loop) yürütür

Kullanım:
    python -m agent.main
"""

import os
import sys
import time
import signal
import tempfile
import threading
import subprocess
import hashlib
from datetime import datetime, timezone

# Proje kök dizinini Python path'ine ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agent.env_resolver import apply_desktop_env, get_desktop_env
from agent.supabase_client import AlertRoxClient
from agent.system_actions import (
    COMMAND_MAP,
    shutdown_now,
    cancel_shutdown,
    get_volume_status,
    get_installed_applications,
    get_running_processes,
    launch_application,
    close_application,
)
from agent.chat_window import AlertRoxChatWindow
from agent.shutdown_window import ShutdownCountdownWindow
from agent.battery_monitor import BatteryMonitor

battery_monitor_instance = None
chat_window_instance = None
shutdown_window_instance = None

HEARTBEAT_INTERVAL = int(os.getenv("HEARTBEAT_INTERVAL", "10"))
COMMAND_POLL_INTERVAL = float(os.getenv("COMMAND_POLL_INTERVAL", "0.5"))
MAX_COMMAND_AGE_SECONDS = 60  # 60 saniyeden eski bekleyen komutlar çalıştırılmaz

running = True
_lock_fd = None


def acquire_single_instance_lock() -> bool:
    """Tekil çalışma kilidini (/run/user/<uid>/alertrox.lock) alır."""
    global _lock_fd
    lock_dir = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    lock_path = os.path.join(lock_dir, "alertrox.lock")
    try:
        _lock_fd = open(lock_path, "w")
        if sys.platform != "win32":
            import fcntl
            fcntl.flock(_lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        else:
            import msvcrt
            msvcrt.locking(_lock_fd.fileno(), msvcrt.LK_NBLCK, 1)

        _lock_fd.write(str(os.getpid()))
        _lock_fd.flush()
        return True
    except (BlockingIOError, OSError, IOError):
        return False


def release_single_instance_lock():
    """Kilit dosyasını serbest bırakır."""
    global _lock_fd
    if _lock_fd:
        try:
            if sys.platform != "win32":
                import fcntl
                fcntl.flock(_lock_fd, fcntl.LOCK_UN)
            _lock_fd.close()
        except Exception:
            pass
        _lock_fd = None


def signal_handler(sig, frame):
    """Düzgün kapanma."""
    global running
    print("\n[AlertRox] Kapatılıyor...")
    running = False


signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def check_env_file_permissions():
    """Linux sistemlerde .env dosyasının izinlerini (0600) denetler."""
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    if os.path.exists(env_path) and os.name == "posix":
        try:
            mode = os.stat(env_path).st_mode & 0o777
            if mode != 0o600:
                print(f"[AlertRox Güvenlik Uyarısı] .env dosya izinleri çok açık ({oct(mode)}).")
                print("[AlertRox Güvenlik] .env dosya izinleri 0600 (yalnızca sahibi okuyabilir) olarak ayarlanıyor...")
                os.chmod(env_path, 0o600)
        except Exception as e:
            print(f"[AlertRox Güvenlik] .env izin kontrolü uyarısı: {e}")


def show_desktop_notification(title: str, message: str):
    """PC masaüstünde görünür bir güvenlik bildirimi gösterir."""
    try:
        env = get_desktop_env()
        if sys.platform.startswith("linux"):
            subprocess.run(
                ["notify-send", "-a", "AlertRox", "-u", "critical", title, message],
                check=False,
                timeout=3,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
            )
        elif sys.platform == "win32":
            ps_script = (
                f"[reflection.assembly]::loadwithpartialname('System.Windows.Forms'); "
                f"[System.Windows.Forms.MessageBox]::Show('{message}', '{title}', 0, 48)"
            )
            subprocess.Popen(
                ["powershell", "-WindowStyle", "Hidden", "-Command", ps_script],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
    except Exception as e:
        print(f"[AlertRox] Masaüstü bildirimi gösterilemedi: {e}")


def heartbeat_loop(client: AlertRoxClient):
    """Düzenli aralıklarla Supabase'e kalp atışı gönderir."""
    while running:
        try:
            client.send_heartbeat()
        except Exception as e:
            print(f"[AlertRox] Heartbeat hatası: {e}")
        time.sleep(HEARTBEAT_INTERVAL)


def health_check_loop(client: AlertRoxClient):
    """Her 60 saniyede bir sistem sağlık durumunu kontrol edip loglar ve veritabanını günceller."""
    while running:
        time.sleep(60)
        try:
            vol = get_volume_status()
            inst_cnt = len(get_installed_applications())
            run_cnt = len(get_running_processes())
            print(
                f"[health] volume={vol.get('volume')}% (muted={vol.get('muted')}) "
                f"apps_installed={inst_cnt} apps_running={run_cnt}"
            )
            client.update_device_state({
                "volume": vol.get("volume", 50),
                "muted": vol.get("muted", False),
            })
        except Exception as e:
            print(f"[health] denetim hatası: {e}")


def cleanup_expired_pending_commands(client: AlertRoxClient):
    """Açılışta bekleyen eski komutları iptal eder."""
    try:
        pending = client.get_pending_commands()
        for cmd in pending:
            client.update_command_status(
                cmd["id"],
                "expired",
                error_message="Agent başlangıcında eski bekleyen komut temizlendi",
            )
        if pending:
            print(f"[AlertRox] 🧹 Açılışta {len(pending)} adet eski bekleyen komut 'expired' yapıldı.")
    except Exception as e:
        print(f"[AlertRox] Başlangıç komut temizleme uyarısı: {e}")


def execute_command(client: AlertRoxClient, command: dict):
    """Tek bir komutu sıkı güvenlik kontrolleriyle çalıştırır."""
    cmd_id = command["id"]
    cmd_type = command["command_type"]
    payload = command.get("payload", {})
    if not isinstance(payload, dict):
        payload = {}

    created_at_str = command.get("created_at")
    if created_at_str:
        try:
            created_at = datetime.fromisoformat(created_at_str.replace("Z", "+00:00"))
            age_seconds = (datetime.now(timezone.utc) - created_at).total_seconds()
            if age_seconds > MAX_COMMAND_AGE_SECONDS:
                print(f"[AlertRox] ⚠️ Komut {age_seconds:.1f} saniye eski (>60s). Çalıştırılmıyor!")
                client.update_command_status(
                    cmd_id,
                    "expired",
                    error_message=f"Komut zaman aşımına uğradı ({int(age_seconds)}s > 60s)",
                )
                client.log_event("command_expired", f"{cmd_type} komutu zaman aşımı nedeniyle iptal edildi")
                return
        except Exception as e:
            print(f"[AlertRox] Tarih doğrulama hatası: {e}")

    print(f"[AlertRox] Güvenli komut alındı: {cmd_type} (ID: {cmd_id[:8]}...)")
    client.update_command_status(cmd_id, "executing")

    # Sohbet penceresi
    if cmd_type in ("open_chat", "chat"):
        global chat_window_instance
        try:
            if not chat_window_instance:
                chat_window_instance = AlertRoxChatWindow(client)
            chat_window_instance.launch()
            client.update_command_status(cmd_id, "completed")
            client.log_event("chat_opened", "PC'de sohbet penceresi açıldı")
            print("[AlertRox] 💬 PC Sohbet penceresi açıldı!")
        except Exception as e:
            print(f"[AlertRox] Sohbet penceresi açma hatası: {e}")
            client.update_command_status(cmd_id, "failed", error_message=str(e))
        return

    # Kapatma komutu (delay doğrulaması: 5..86400)
    if cmd_type == "shutdown":
        global shutdown_window_instance
        try:
            delay = int(payload.get("delay", 10))
        except (ValueError, TypeError):
            client.update_command_status(cmd_id, "failed", error_message="Geçersiz delay parametresi")
            return

        delay = max(5, min(86400, delay))
        allow_cancel = bool(payload.get("allow_cancel", False))

        def _on_timeout():
            print("[AlertRox] ⚠️ Kapanma sayacı tamamlandı! Bilgisayar kapatılıyor...")
            shutdown_now()

        def _on_cancel():
            print("[AlertRox] ℹ️ Kapanma PC başındaki kullanıcı tarafından iptal edildi.")
            client.log_event("shutdown_cancelled", "Kullanıcı PC üzerinden kapatmayı iptal etti")

        if shutdown_window_instance and shutdown_window_instance.is_active:
            shutdown_window_instance.cancel()

        shutdown_window_instance = ShutdownCountdownWindow(
            delay_seconds=delay,
            on_cancel=_on_cancel,
            on_timeout=_on_timeout,
            allow_cancel=allow_cancel,
        )
        shutdown_window_instance.show()

        client.update_command_status(cmd_id, "completed")
        client.log_event(
            "shutdown_scheduled",
            f"Bilgisayar {delay} saniye sonra kapanacak (PC iptali: {'açık' if allow_cancel else 'kilitli'})",
        )
        print(f"[AlertRox] ⏳ {delay} saniyelik kapanma sayacı başlatıldı! (PC iptali: {allow_cancel})")
        return

    # Kapatmayı iptal etme
    if cmd_type in ("cancel_shutdown", "shutdown_cancel"):
        if shutdown_window_instance and shutdown_window_instance.is_active:
            shutdown_window_instance.cancel()
        cancel_shutdown()
        client.update_command_status(cmd_id, "completed")
        client.log_event("shutdown_cancelled", "Telefondan kapatma iptal edildi")
        print("[AlertRox] 🛑 Kapatma emri iptal edildi!")
        return

    # Ses seviyesi ayarlama
    if cmd_type == "set_volume":
        vol = payload.get("volume", 50)
        success, message = COMMAND_MAP["set_volume"]["func"](vol)
        curr = get_volume_status()
        client.update_device_state({"volume": curr["volume"], "muted": curr["muted"]})
        if success:
            client.update_command_status(cmd_id, "completed")
            client.log_event("volume_changed", f"PC ses seviyesi %{vol} olarak ayarlandı")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Ses adımı (+/- 5%)
    if cmd_type == "volume_step":
        delta = int(payload.get("delta", 5))
        success, message = COMMAND_MAP["volume_step"]["func"](delta)
        curr = get_volume_status()
        client.update_device_state({"volume": curr["volume"], "muted": curr["muted"]})
        if success:
            client.update_command_status(cmd_id, "completed")
            client.log_event("volume_changed", f"PC ses adımı uygulandı ({delta})")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Sesi aç/kapat (Mute)
    if cmd_type == "toggle_mute":
        success, message = COMMAND_MAP["toggle_mute"]["func"]()
        curr = get_volume_status()
        client.update_device_state({"volume": curr["volume"], "muted": curr["muted"]})
        if success:
            client.update_command_status(cmd_id, "completed")
            client.log_event("volume_mute_toggled", "PC ses sessize alma durumu değiştirildi")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Kesin Mute ayarı
    if cmd_type == "set_mute":
        muted = bool(payload.get("muted", False))
        success, message = COMMAND_MAP["set_mute"]["func"](muted)
        curr = get_volume_status()
        client.update_device_state({"volume": curr["volume"], "muted": curr["muted"]})
        if success:
            client.update_command_status(cmd_id, "completed")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Ses durumunu sorgulama
    if cmd_type == "get_volume":
        vol_info = get_volume_status()
        client.update_device_state({"volume": vol_info["volume"], "muted": vol_info["muted"]})
        client.update_command_status(cmd_id, "completed")
        client.client.table("commands").update({"payload": vol_info}).eq("id", cmd_id).execute()
        return

    # Medya kontrolü (play_pause, next, previous)
    if cmd_type == "media_control":
        action = payload.get("action", "play_pause")
        success, message = COMMAND_MAP["media_control"]["func"](action)
        if success:
            client.update_command_status(cmd_id, "completed")
            client.log_event("media_controlled", f"Medya kontrolü uygulandı: {action}")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Uygulama başlatma
    if cmd_type == "launch_app":
        app_id = payload.get("app_id") or payload.get("exec") or payload.get("name", "")
        app_name = payload.get("name", app_id)
        success, message = launch_application(app_id)
        if success:
            show_desktop_notification("AlertRox", f"{app_name} başlatıldı")
            client.update_command_status(cmd_id, "completed")
            client.log_event("app_launched", f"Telefondan PC'de uygulama başlatıldı: {app_name}")
            # Uygulama açılınca anında açık uygulamaları güncelle
            try:
                time.sleep(0.5)
                client.update_device_state({"running_apps": get_running_processes()})
            except Exception:
                pass
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Uygulama / Süreç kapatma
    if cmd_type in ("close_app", "kill_process"):
        app_target = payload.get("app_id") or payload.get("pid") or 0
        pname = payload.get("name", f"Hedef: {app_target}")
        success, message = close_application(app_target)
        if success:
            client.update_command_status(cmd_id, "completed")
            client.log_event("process_killed", f"Telefondan süreç/uygulama sonlandırıldı: {pname}")
            # Uygulama kapanınca anında açık uygulamaları güncelle
            try:
                client.update_device_state({"running_apps": get_running_processes()})
            except Exception:
                pass
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
        return

    # Yüklü uygulamaları listeleme isteği
    if cmd_type == "get_installed_apps":
        apps = get_installed_applications()
        client.update_device_state({"installed_apps": apps})
        client.update_command_status(cmd_id, "completed")
        client.client.table("commands").update({"payload": {"apps": apps}}).eq("id", cmd_id).execute()
        return

    # Çalışan uygulamaları listeleme isteği
    if cmd_type == "get_running_apps":
        procs = get_running_processes()
        client.update_device_state({"running_apps": procs})
        client.update_command_status(cmd_id, "completed")
        client.client.table("commands").update({"payload": {"processes": procs}}).eq("id", cmd_id).execute()
        return

    # Her iki listeyi yenileme
    if cmd_type == "refresh_apps":
        apps = get_installed_applications()
        procs = get_running_processes()
        client.update_device_state({"installed_apps": apps, "running_apps": procs})
        client.update_command_status(cmd_id, "completed")
        client.client.table("commands").update({"payload": {"apps": apps, "processes": procs}}).eq("id", cmd_id).execute()
        return

    # Komut haritası kontrolü
    if cmd_type not in COMMAND_MAP:
        client.update_command_status(cmd_id, "failed", error_message=f"Bilinmeyen komut: {cmd_type}")
        print(f"[AlertRox] Bilinmeyen komut: {cmd_type}")
        return

    cmd_info = COMMAND_MAP[cmd_type]
    has_file = cmd_info["has_file"]

    # Gizlilik & Güvenlik Bildirimi (Webcam / Mikrofon / Ekran Görüntüsü)
    if cmd_type == "webcam":
        show_desktop_notification("AlertRox Güvenlik Uyarısı", "Web kamerasından fotoğraf çekildi.")
        client.log_event("privacy_alert", "Kullanıcı bilgilendirildi: Webcam kullanıldı")
    elif cmd_type == "mic_record":
        show_desktop_notification("AlertRox Güvenlik Uyarısı", "Mikrofon kaydı yapıldı.")
        client.log_event("privacy_alert", "Kullanıcı bilgilendirildi: Mikrofon kullanıldı")
    elif cmd_type == "screenshot":
        show_desktop_notification("AlertRox Güvenlik Uyarısı", "Ekran görüntüsü alındı.")
        client.log_event("privacy_alert", "Kullanıcı bilgilendirildi: Ekran görüntüsü alındı")

    try:
        # mic_record süresi doğrulaması: 1..120
        if cmd_type == "mic_record":
            try:
                duration = int(payload.get("duration", 10))
            except (ValueError, TypeError):
                client.update_command_status(cmd_id, "failed", error_message="Geçersiz duration parametresi")
                return
            duration = max(1, min(120, duration))
            success, message, *rest = cmd_info["func"](duration)
        elif cmd_type == "shutdown":
            delay = max(5, min(86400, int(payload.get("delay", 60))))
            success, message, *rest = cmd_info["func"](delay)
        else:
            success, message, *rest = cmd_info["func"]()

        file_path = rest[0] if rest else None

        if success:
            result_url = None
            if has_file and file_path:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                ext = file_path.rsplit(".", 1)[-1]
                storage_path = f"{client.device_id}/{cmd_type}/{timestamp}.{ext}"

                print(f"[AlertRox] Dosya güvenli yükleniyor: {storage_path}")
                result_url = client.upload_file(file_path, storage_path)

                try:
                    os.remove(file_path)
                except OSError:
                    pass

            client.update_command_status(cmd_id, "completed", result_url=result_url)
            client.log_event("command_executed", f"{cmd_info['description']} - {message}")
            print(f"[AlertRox] ✅ Komut başarılı: {message}")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
            print(f"[AlertRox] ❌ Komut başarısız: {message}")

    except Exception as e:
        client.update_command_status(cmd_id, "failed", error_message=str(e))
        print(f"[AlertRox] ❌ Komut hatası: {e}")


def command_listener_loop(client: AlertRoxClient):
    """Supabase'den bekleyen komutları çeker ve anında çalıştırır."""
    while running:
        found_any = False
        try:
            commands = client.get_pending_commands()
            if commands:
                found_any = True
                for cmd in commands:
                    execute_command(client, cmd)
        except Exception as e:
            print(f"[AlertRox] Komut dinleme hatası: {e}")
        # Komut varsa hemen sonrakine bak, yoksa 0.5s bekle (hızlı tepki)
        time.sleep(0.1 if found_any else COMMAND_POLL_INTERVAL)


def main():
    """AlertRox PC Agent güvenli başlangıç noktası."""
    print("=" * 50)
    print("  🚨 AlertRox PC Agent (Sertleştirilmiş Güvenlik)")
    print("=" * 50)

    # 1. Tek örnek kilidini al (aynı anda birden fazla agent çalışmasını önler)
    if not acquire_single_instance_lock():
        print("[AlertRox] ⚠️ AlertRox zaten arka planda çalışıyor! Başka bir örnek tespit edildi.")
        print("[AlertRox] Çakışmayı önlemek için bu kopya sonlandırılıyor.")
        print("Durumu görmek için: ./scripts/alertrox-status.sh veya 'systemctl --user status alertrox'")
        sys.exit(0)

    # 2. Dinamik masaüstü ortamını çöz ve uygula
    apply_desktop_env()

    # 3. .env izinlerini denetle
    check_env_file_permissions()

    try:
        client = AlertRoxClient()
    except Exception as e:
        print(f"\n❌ HATA: {e}")
        print("\nÇözüm:")
        print("1. .env.example dosyasını .env olarak kopyalayın")
        print("2. SUPABASE_URL, SUPABASE_ANON_KEY, AGENT_EMAIL ve AGENT_PASSWORD girin")
        release_single_instance_lock()
        sys.exit(1)

    # Açılışta eski bekleyen komutları temizle
    cleanup_expired_pending_commands(client)

    # Cihazı kaydet ve boot sinyali gönder
    client.register_device()
    client.log_event("boot", f"PC açıldı — {client.device_name} ({client._get_local_ip()})")
    print(f"\n[AlertRox] 🟢 Boot sinyali gönderildi!")

    heartbeat_thread = threading.Thread(target=heartbeat_loop, args=(client,), daemon=True)
    heartbeat_thread.start()
    print(f"[AlertRox] 💓 Heartbeat aktif (her {HEARTBEAT_INTERVAL}s)")

    command_thread = threading.Thread(target=command_listener_loop, args=(client,), daemon=True)
    command_thread.start()
    print(f"[AlertRox] 👂 Hızlı komut dinleyici aktif (gecikme: <500ms, max_age: 60s)")

    health_thread = threading.Thread(target=health_check_loop, args=(client,), daemon=True)
    health_thread.start()
    print("[AlertRox] 🩺 Sağlık gözcüsü aktif (her 60s)")

    # Arka plan sohbet dinleyicisini başlat (Telefondan mesaj gelince otomatik pencere açılır)
    global chat_window_instance, battery_monitor_instance
    try:
        chat_window_instance = AlertRoxChatWindow(client)
        chat_window_instance.start_background_listener()
        print("[AlertRox] 💬 Sohbet arka plan dinleyicisi aktif!")
    except Exception as e:
        print(f"[AlertRox] ⚠️ Sohbet dinleyicisi başlatılamadı: {e}")

    # Laptop pil & güç durumu gözcüsünü başlat
    try:
        battery_monitor_instance = BatteryMonitor(client)
        battery_monitor_instance.start()
    except Exception as e:
        print(f"[AlertRox] ⚠️ Pil gözcüsü başlatılamadı: {e}")

    print(f"\n[AlertRox] Çalışıyor... (Durdurmak için Ctrl+C)\n")

    try:
        while running:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        print("\n[AlertRox] Çevrimdışı olarak işaretleniyor...")
        try:
            client.set_offline()
            client.log_event("shutdown", "PC Agent kapatıldı")
        except Exception:
            pass
        release_single_instance_lock()
        print("[AlertRox] 👋 Güle güle!")


if __name__ == "__main__":
    main()
