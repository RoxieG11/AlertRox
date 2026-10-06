"""
AlertRox — Supabase Bağlantı Katmanı (Güvenli Kimlik Doğrulama)

Tüm Supabase işlemleri (veritabanı CRUD + Storage) bu modülden yapılır.
Artık service_role KULLANILMAZ. Anon Key + Supabase Auth (Email & Password)
ile authenticated oturum üzerinden RLS korumalı çalışır.
"""

import os
import uuid
import platform
import socket
from datetime import datetime, timezone
from dotenv import load_dotenv
from supabase import create_client, Client


# .env dosyasını yükle
load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")
AGENT_EMAIL = os.getenv("AGENT_EMAIL")
AGENT_PASSWORD = os.getenv("AGENT_PASSWORD")
DEVICE_NAME = os.getenv("DEVICE_NAME", socket.gethostname())
DEVICE_ID = os.getenv("DEVICE_ID", "")


def _generate_device_id() -> str:
    """Makineye özgü benzersiz bir ID üretir."""
    if DEVICE_ID:
        return DEVICE_ID
    # Hostname + platform bazlı basit bir ID
    raw = f"{socket.gethostname()}-{platform.node()}-{platform.system()}"
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, raw))


class AlertRoxClient:
    """Supabase ile tüm iletişimi yöneten kimliği doğrulanmış istemci sınıfı."""

    def __init__(self):
        if not SUPABASE_URL or not SUPABASE_ANON_KEY:
            raise ValueError(
                "SUPABASE_URL ve SUPABASE_ANON_KEY .env dosyasında tanımlanmalı!\n"
                ".env.example dosyasını .env olarak kopyalayıp bilgileri girin."
            )

        if not AGENT_EMAIL or not AGENT_PASSWORD:
            raise ValueError(
                "AGENT_EMAIL ve AGENT_PASSWORD .env dosyasında tanımlanmalı!\n"
                "Supabase Dashboard'dan oluşturduğunuz kullanıcı bilgilerini .env içine yazın."
            )

        self.client: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        self.device_id = _generate_device_id()
        self.device_name = DEVICE_NAME
        self.email = AGENT_EMAIL
        self.password = AGENT_PASSWORD

        # Kimlik doğrula (Sign In with Email & Password)
        self._authenticate()

        print(f"[AlertRox] Supabase güvenli bağlantısı kuruldu (Auth: {self.email})")
        print(f"[AlertRox] Cihaz ID: {self.device_id}")
        print(f"[AlertRox] Cihaz Adı: {self.device_name}")

    def _authenticate(self):
        """Supabase Auth üzerinden oturum açar."""
        try:
            res = self.client.auth.sign_in_with_password({
                "email": self.email,
                "password": self.password,
            })
            if not res or not res.session:
                raise ValueError("Oturum açılamadı: Geçersiz kullanıcı oturumu.")
            self.user_id = res.user.id
        except Exception as e:
            raise RuntimeError(f"Supabase kimlik doğrulama hatası: {e}")

    def ensure_authenticated(self):
        """Oturum süresi dolmuşsa token'ı yeniler veya yeniden giriş yapar."""
        try:
            session = self.client.auth.get_session()
            if not session or not session.access_token:
                self._authenticate()
            elif hasattr(session, "expires_at") and session.expires_at:
                # 60 saniyeden az kaldıysa yenile
                now_ts = int(datetime.now(timezone.utc).timestamp())
                if session.expires_at - now_ts < 60:
                    try:
                        self.client.auth.refresh_session()
                    except Exception:
                        self._authenticate()
        except Exception:
            self._authenticate()

    # ─────────────────────────────────────────
    # Cihaz İşlemleri (devices tablosu)
    # ─────────────────────────────────────────

    def register_device(self) -> dict:
        """Cihazı kaydet veya güncelle (upsert)."""
        self.ensure_authenticated()
        mac_addr = self._get_mac_address()
        data = {
            "device_id": self.device_id,
            "owner_id": self.user_id,
            "name": self.device_name,
            "status": "online",
            "last_boot": datetime.now(timezone.utc).isoformat(),
            "last_heartbeat": datetime.now(timezone.utc).isoformat(),
            "ip_address": self._get_local_ip(),
            "os_info": f"{platform.system()} {platform.release()} ({platform.machine()}) | MAC:{mac_addr}",
        }

        result = (
            self.client.table("devices")
            .upsert(data, on_conflict="device_id")
            .execute()
        )
        print(f"[AlertRox] Cihaz kaydedildi: {self.device_name}")
        return result.data

    def send_heartbeat(self) -> None:
        """Kalp atışı gönder (canlı gösterge için)."""
        self.ensure_authenticated()
        self.client.table("devices").update({
            "status": "online",
            "last_heartbeat": datetime.now(timezone.utc).isoformat(),
        }).eq("device_id", self.device_id).execute()

    def set_offline(self) -> None:
        """Cihazı çevrimdışı olarak işaretle."""
        self.ensure_authenticated()
        self.client.table("devices").update({
            "status": "offline",
        }).eq("device_id", self.device_id).execute()
        print("[AlertRox] Cihaz çevrimdışı olarak işaretlendi")

    def get_device_status(self, device_id: str = None) -> dict | None:
        """Cihaz durumunu sorgula."""
        self.ensure_authenticated()
        target = device_id or self.device_id
        result = (
            self.client.table("devices")
            .select("*")
            .eq("device_id", target)
            .execute()
        )
        return result.data[0] if result.data else None

    # ─────────────────────────────────────────
    # Komut İşlemleri (commands tablosu)
    # ─────────────────────────────────────────

    def get_pending_commands(self) -> list:
        """Bu cihaz için bekleyen komutları getir."""
        self.ensure_authenticated()
        result = (
            self.client.table("commands")
            .select("*")
            .eq("device_id", self.device_id)
            .eq("status", "pending")
            .order("created_at")
            .execute()
        )
        return result.data

    def update_command_status(
        self,
        command_id: str,
        status: str,
        result_url: str = None,
        error_message: str = None,
    ) -> None:
        """Komut durumunu güncelle."""
        self.ensure_authenticated()
        data = {
            "status": status,
            "executed_at": datetime.now(timezone.utc).isoformat(),
        }
        if result_url:
            data["result_url"] = result_url
        if error_message:
            data["error_message"] = error_message

        self.client.table("commands").update(data).eq("id", command_id).execute()

    def send_command(self, device_id: str, command_type: str, payload: dict = None) -> dict:
        """
        Bir cihaza komut gönder.
        command_type: 'shutdown' | 'lock' | 'screenshot' | 'webcam' | 'mic_record' | 'cancel_shutdown' | 'logout' | 'open_chat'
        """
        self.ensure_authenticated()
        data = {
            "device_id": device_id,
            "owner_id": self.user_id,
            "command_type": command_type,
            "status": "pending",
            "payload": payload or {},
        }
        result = self.client.table("commands").insert(data).execute()
        return result.data[0] if result.data else {}

    def get_command_status(self, command_id: str) -> dict | None:
        """Belirli bir komutun durumunu ve sonucunu getir."""
        self.ensure_authenticated()
        result = (
            self.client.table("commands")
            .select("*")
            .eq("id", command_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def get_latest_media(self, device_id: str = None, limit: int = 5) -> list:
        """Cihazın son tamamlanan medya sonuçlarını getir."""
        self.ensure_authenticated()
        target = device_id or self.device_id
        result = (
            self.client.table("commands")
            .select("*")
            .eq("device_id", target)
            .eq("status", "completed")
            .not_.is_("result_url", "null")
            .order("executed_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data

    # ─────────────────────────────────────────
    # Olay Geçmişi (activity_log tablosu)
    # ─────────────────────────────────────────

    def log_event(self, event_type: str, message: str) -> None:
        """Olay logla."""
        self.ensure_authenticated()
        self.client.table("activity_log").insert({
            "device_id": self.device_id,
            "owner_id": self.user_id,
            "event_type": event_type,
            "message": message,
        }).execute()

    def get_activity_log(self, limit: int = 50) -> list:
        """Son olayları getir."""
        self.ensure_authenticated()
        result = (
            self.client.table("activity_log")
            .select("*")
            .eq("device_id", self.device_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data

    # ─────────────────────────────────────────
    # Canlı Chat İşlemleri (messages tablosu)
    # ─────────────────────────────────────────

    def send_chat_message(self, sender: str, text: str) -> dict:
        """Sohbet mesajı gönder ('pc' veya 'mobile')."""
        self.ensure_authenticated()
        data = {
            "device_id": self.device_id,
            "owner_id": self.user_id,
            "sender": sender,
            "text": text,
        }
        res = self.client.table("messages").insert(data).execute()
        return res.data[0] if res.data else {}

    def get_chat_messages(self, limit: int = 30) -> list:
        """Son sohbet mesajlarını getir."""
        self.ensure_authenticated()
        result = (
            self.client.table("messages")
            .select("*")
            .eq("device_id", self.device_id)
            .order("created_at", desc=False)
            .limit(limit)
            .execute()
        )
        return result.data

    def clear_chat_messages(self) -> None:
        """Tüm sohbet mesajlarını siler."""
        self.ensure_authenticated()
        self.client.table("messages").delete().eq("device_id", self.device_id).execute()

    # ─────────────────────────────────────────
    # Storage İşlemleri (alertrox-files bucket)
    # ─────────────────────────────────────────

    def upload_file(self, file_path: str, storage_path: str) -> str:
        """
        Dosyayı Supabase Storage'a yükle.
        Dönüş: Dosyanın 600 saniye (10 dakika) geçerli signed URL'i.
        """
        self.ensure_authenticated()
        with open(file_path, "rb") as f:
            file_data = f.read()

        self.client.storage.from_("alertrox-files").upload(
            storage_path,
            file_data,
            file_options={"content-type": self._guess_content_type(storage_path)},
        )

        # 600 saniyelik (10 dakika) geçici güvenli indirme linki oluştur
        signed = self.client.storage.from_("alertrox-files").create_signed_url(
            storage_path, 600
        )
        return signed.get("signedURL", "")

    # ─────────────────────────────────────────
    # Yardımcı Fonksiyonlar
    # ─────────────────────────────────────────

    @staticmethod
    def _get_local_ip() -> str:
        """Yerel IP adresini bul."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "Bilinmiyor"

    @staticmethod
    def _guess_content_type(path: str) -> str:
        """Dosya uzantısına göre content-type belirle."""
        ext = path.rsplit(".", 1)[-1].lower()
        types = {
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "wav": "audio/wav",
            "mp3": "audio/mpeg",
        }
        return types.get(ext, "application/octet-stream")

    @staticmethod
    def _get_mac_address() -> str:
        """Sistemin birincil MAC adresini bulur."""
        try:
            import uuid
            node = uuid.getnode()
            return ":".join(["{:02x}".format((node >> ele) & 0xFF) for ele in range(0, 8 * 6, 8)][::-1])
        except Exception:
            return "00:00:00:00:00:00"
