"""
AlertRox — PC Agent Ana Modülü

Bu script bilgisayar açıldığında otomatik olarak çalışır ve:
1. Supabase'e "Ben açıldım!" sinyali gönderir
2. Her 10 saniyede bir heartbeat (kalp atışı) gönderir
3. Telefondan gelen komutları dinler ve çalıştırır

Kullanım:
    python -m agent.main
"""

import os
import sys
import time
import signal
import threading
from datetime import datetime

# Proje kök dizinini Python path'ine ekle
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agent.supabase_client import AlertRoxClient
from agent.system_actions import COMMAND_MAP
from agent.chat_window import AlertRoxChatWindow

chat_window_instance = None


# ─────────────────────────────────────────
# Ayarlar
# ─────────────────────────────────────────

HEARTBEAT_INTERVAL = int(os.getenv("HEARTBEAT_INTERVAL", "10"))   # saniye
COMMAND_POLL_INTERVAL = int(os.getenv("COMMAND_POLL_INTERVAL", "3"))  # saniye

# Graceful shutdown için flag
running = True


def signal_handler(sig, frame):
    """Ctrl+C ile düzgün kapanma."""
    global running
    print("\n[AlertRox] Kapatılıyor...")
    running = False


signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


# ─────────────────────────────────────────
# Heartbeat Thread
# ─────────────────────────────────────────

def heartbeat_loop(client: AlertRoxClient):
    """Düzenli aralıklarla Supabase'e 'hala açığım' sinyali gönderir."""
    while running:
        try:
            client.send_heartbeat()
        except Exception as e:
            print(f"[AlertRox] Heartbeat hatası: {e}")
        time.sleep(HEARTBEAT_INTERVAL)


# ─────────────────────────────────────────
# Komut Çalıştırıcı
# ─────────────────────────────────────────

def execute_command(client: AlertRoxClient, command: dict):
    """Tek bir komutu çalıştır ve sonucu Supabase'e bildir."""
    cmd_id = command["id"]
    cmd_type = command["command_type"]
    payload = command.get("payload", {})

    print(f"[AlertRox] Komut alındı: {cmd_type} (ID: {cmd_id[:8]}...)")

    # Komutu "çalıştırılıyor" olarak işaretle
    client.update_command_status(cmd_id, "executing")

    # Sohbet penceresi açma komutu
    if cmd_type == "open_chat":
        global chat_window_instance
        if not chat_window_instance:
            chat_window_instance = AlertRoxChatWindow(client)
        chat_window_instance.launch()
        client.update_command_status(cmd_id, "completed")
        client.log_event("chat_opened", "PC'de sohbet penceresi açıldı")
        print("[AlertRox] 💬 PC Sohbet penceresi açıldı!")
        return

    # Komut haritasında var mı kontrol et
    if cmd_type not in COMMAND_MAP:
        client.update_command_status(
            cmd_id, "failed", error_message=f"Bilinmeyen komut: {cmd_type}"
        )
        print(f"[AlertRox] Bilinmeyen komut: {cmd_type}")
        return

    cmd_info = COMMAND_MAP[cmd_type]
    has_file = cmd_info["has_file"]

    try:
        # Komutu çalıştır
        if cmd_type == "mic_record":
            duration = payload.get("duration", 10)
            success, message, *rest = cmd_info["func"](duration)
        elif cmd_type == "shutdown":
            delay = payload.get("delay", 60)
            success, message, *rest = cmd_info["func"](delay)
        else:
            success, message, *rest = cmd_info["func"]()

        file_path = rest[0] if rest else None

        if success:
            result_url = None

            # Dosya üreten komutlarda dosyayı Storage'a yükle
            if has_file and file_path:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                ext = file_path.rsplit(".", 1)[-1]
                storage_path = f"{client.device_id}/{cmd_type}/{timestamp}.{ext}"

                print(f"[AlertRox] Dosya yükleniyor: {storage_path}")
                result_url = client.upload_file(file_path, storage_path)

                # Geçici dosyayı temizle
                try:
                    os.remove(file_path)
                except OSError:
                    pass

            # Başarılı olarak işaretle
            client.update_command_status(cmd_id, "completed", result_url=result_url)

            # Olay logla
            client.log_event(
                "command_executed",
                f"{cmd_info['description']} - {message}",
            )
            print(f"[AlertRox] ✅ Komut başarılı: {message}")
        else:
            client.update_command_status(cmd_id, "failed", error_message=message)
            print(f"[AlertRox] ❌ Komut başarısız: {message}")

    except Exception as e:
        client.update_command_status(cmd_id, "failed", error_message=str(e))
        print(f"[AlertRox] ❌ Komut hatası: {e}")


# ─────────────────────────────────────────
# Komut Dinleyici Döngüsü
# ─────────────────────────────────────────

def command_listener_loop(client: AlertRoxClient):
    """Supabase'den bekleyen komutları çeker ve çalıştırır."""
    while running:
        try:
            commands = client.get_pending_commands()
            for cmd in commands:
                execute_command(client, cmd)
        except Exception as e:
            print(f"[AlertRox] Komut dinleme hatası: {e}")
        time.sleep(COMMAND_POLL_INTERVAL)


# ─────────────────────────────────────────
# Ana Giriş Noktası
# ─────────────────────────────────────────

def main():
    """AlertRox PC Agent başlangıç noktası."""
    print("=" * 50)
    print("  🚨 AlertRox PC Agent")
    print("  Bilgisayarın gözcüsü aktif!")
    print("=" * 50)

    # Supabase bağlantısı kur
    try:
        client = AlertRoxClient()
    except ValueError as e:
        print(f"\n❌ HATA: {e}")
        print("\nÇözüm:")
        print("1. .env.example dosyasını .env olarak kopyalayın")
        print("2. Supabase bilgilerinizi .env dosyasına girin")
        sys.exit(1)

    # Cihazı kaydet ve boot sinyali gönder
    client.register_device()
    client.log_event("boot", f"PC açıldı — {client.device_name} ({client._get_local_ip()})")
    print(f"\n[AlertRox] 🟢 Boot sinyali gönderildi!")

    # Heartbeat thread'ini başlat
    heartbeat_thread = threading.Thread(target=heartbeat_loop, args=(client,), daemon=True)
    heartbeat_thread.start()
    print(f"[AlertRox] 💓 Heartbeat aktif (her {HEARTBEAT_INTERVAL} saniye)")

    # Komut dinleyici thread'ini başlat
    command_thread = threading.Thread(target=command_listener_loop, args=(client,), daemon=True)
    command_thread.start()
    print(f"[AlertRox] 👂 Komut dinleyici aktif (her {COMMAND_POLL_INTERVAL} saniye)")

    print(f"\n[AlertRox] Çalışıyor... (Durdurmak için Ctrl+C)\n")

    # Ana thread'i canlı tut
    try:
        while running:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        # Kapanırken çevrimdışı olarak işaretle
        print("\n[AlertRox] Çevrimdışı olarak işaretleniyor...")
        try:
            client.set_offline()
            client.log_event("shutdown", "PC Agent kapatıldı")
        except Exception:
            pass
        print("[AlertRox] 👋 Güle güle!")


if __name__ == "__main__":
    main()
