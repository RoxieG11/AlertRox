"""
AlertRox — Laptop Pil & Güç Durumu İzleyici

Bilgisayar şarjdan çekildiğinde veya pil %20'nin altına düştüğünde
anında Supabase activity_log tablosuna kritik olay kaydeder ve masaüstünde bildirim gösterir.
Telefondaki AlertRox Watchdog servisi bu olayı anında yakalayarak telefonun
bildirim çubuğunda yüksek öncelikli sesli & titreşimli alarm çalar.
"""

import time
import threading
import psutil
from datetime import datetime, timezone
from agent.supabase_client import AlertRoxClient

class BatteryMonitor:
    def __init__(self, client: AlertRoxClient, check_interval: int = 5):
        self.client = client
        self.check_interval = check_interval
        self._running = False
        self._thread = None
        self._last_plugged = None
        self._last_low_notified = False

    def start(self):
        """Arka planda pil izleme iş parçacığını başlatır."""
        # Eğer sistemde pil sensörü yoksa (Masaüstü PC vb.) izlemeyi başlatma
        battery = psutil.sensors_battery()
        if battery is None:
            print("[AlertRox Pil] Masaüstü sistem algılandı (pil sensörü yok).")
            return

        self._running = True
        self._last_plugged = battery.power_plugged
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()
        print(f"[AlertRox Pil] 🔋 Laptop pil gözcüsü aktif (Şarj: %{int(battery.percent)}, Fişte: {battery.power_plugged})")

    def stop(self):
        self._running = False

    def get_battery_info(self) -> dict:
        """Anlık pil yüzdesi ve fiş durumunu döndürür."""
        battery = psutil.sensors_battery()
        if battery is None:
            return {"has_battery": False, "percent": 100, "plugged": True}
        return {
            "has_battery": True,
            "percent": int(battery.percent),
            "plugged": bool(battery.power_plugged),
            "secsleft": battery.secsleft if battery.secsleft > 0 else None,
        }

    def _monitor_loop(self):
        while self._running:
            try:
                battery = psutil.sensors_battery()
                if battery is not None:
                    percent = int(battery.percent)
                    plugged = bool(battery.power_plugged)

                    # 1. Şarjdan çekilme durumu kontrolü
                    if self._last_plugged is True and not plugged:
                        print(f"[AlertRox Pil] ⚠️ Laptop şarjdan çekildi! Pil: %{percent}")
                        self.client.log_event(
                            "power_unplugged",
                            f"Laptop şarjdan çekildi! Pil seviyesi: %{percent}",
                        )

                    # 2. Şarja geri takılma durumu kontrolü
                    elif self._last_plugged is False and plugged:
                        print(f"[AlertRox Pil] 🔌 Laptop şarja takıldı! Pil: %{percent}")
                        self.client.log_event(
                            "power_plugged",
                            f"Laptop şarja takıldı. Pil seviyesi: %{percent}",
                        )
                        self._last_low_notified = False

                    self._last_plugged = plugged

                    # 3. Kritik Düşük Pil Uyarısı (%20 ve altı, şarjda değilken)
                    if percent <= 20 and not plugged:
                        if not self._last_low_notified:
                            print(f"[AlertRox Pil] 🚨 KRİTİK PİL UYARISI: %{percent}")
                            self.client.log_event(
                                "battery_critical_low",
                                f"Kritik Düşük Pil: %{percent} kaldı! Lütfen şarja takın.",
                            )
                            self._last_low_notified = True
                    elif percent > 25:
                        self._last_low_notified = False

            except Exception as e:
                print(f"[AlertRox Pil] İzleme hatası: {e}")

            time.sleep(self.check_interval)
