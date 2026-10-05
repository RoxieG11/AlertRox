"""
AlertRox — Bilgisayar Kapanma Geri Sayım Penceresi (Tkinter)

Telefondan kapatma emri verildiğinde PC ekranında beliren,
canlı geri sayım yapan ve iptal butonu sunan modern pencere.
"""

import threading
import time
import tkinter as tk
from tkinter import ttk


class ShutdownCountdownWindow:
    """PC ekranında görünen canlı kapanma geri sayım penceresi."""

    def __init__(self, delay_seconds: int = 10, on_cancel=None, on_timeout=None, allow_cancel: bool = False):
        self.total_seconds = max(5, int(delay_seconds))
        self.remaining_seconds = self.total_seconds
        self.on_cancel = on_cancel
        self.on_timeout = on_timeout
        self.allow_cancel = allow_cancel
        self.root = None
        self.is_active = False
        self._thread = None
        self._timer_running = False

    def show(self):
        """Pencereyi ayrı bir thread içinde açar."""
        if self.is_active:
            return
        self._thread = threading.Thread(target=self._run_gui, daemon=True)
        self._thread.start()

    def cancel(self):
        """Dışarıdan (örneğin telefondan gelen iptal emriyle) kapatmayı iptal eder."""
        self._timer_running = False
        self.is_active = False
        if self.root:
            try:
                self.root.after(0, self._destroy_window)
            except Exception:
                pass

    def _destroy_window(self):
        if self.root:
            try:
                self.root.destroy()
            except Exception:
                pass
            self.root = None

    def _run_gui(self):
        self.root = tk.Tk()
        self.root.title("AlertRox — Bilgisayar Kapatılıyor")
        self.root.geometry("420x260")
        self.root.resizable(False, False)
        self.is_active = True

        # Her zaman en üstte tut ve ekranın ortasına konumlandır
        self.root.attributes("-topmost", True)
        self.root.update_idletasks()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        x = (sw - 420) // 2
        y = (sh - 260) // 2
        self.root.geometry(f"420x260+{x}+{y}")

        # Renk Paleti (AlertRox Koyu / Kırmızı Uyarı)
        bg_dark = "#0B0F19"
        bg_card = "#161F30"
        accent_red = "#EF4444"
        fg_white = "#F8FAFC"
        fg_muted = "#94A3B8"

        self.root.configure(bg=bg_dark)

        # ── Başlık Barı ──
        header = tk.Frame(self.root, bg=bg_card, height=48)
        header.pack(fill=tk.X)

        title_lbl = tk.Label(
            header,
            text="⚠️  AlertRox Uzaktan Kapatma",
            font=("Segoe UI", 11, "bold"),
            bg=bg_card,
            fg=accent_red,
            padx=14,
            pady=10,
        )
        title_lbl.pack(side=tk.LEFT)

        # ── Gövde ──
        body = tk.Frame(self.root, bg=bg_dark, padx=20, pady=16)
        body.pack(fill=tk.BOTH, expand=True)

        desc_lbl = tk.Label(
            body,
            text="Telefondan bilgisayarı kapatma emri verildi.",
            font=("Segoe UI", 10),
            bg=bg_dark,
            fg=fg_muted,
        )
        desc_lbl.pack(pady=(0, 8))

        # Canlı Kalan Süre Sayacı
        self.countdown_lbl = tk.Label(
            body,
            text=self._format_time(self.remaining_seconds),
            font=("Segoe UI", 36, "bold"),
            bg=bg_dark,
            fg=accent_red,
        )
        self.countdown_lbl.pack(pady=4)

        info_lbl = tk.Label(
            body,
            text="Süre dolduğunda bilgisayar otomatik olarak kapanacaktır.",
            font=("Segoe UI", 9),
            bg=bg_dark,
            fg=fg_muted,
        )
        info_lbl.pack(pady=(0, 14))

        # ── İptal Et Butonu veya Kilit Bildirimi ──
        if self.allow_cancel:
            cancel_btn = tk.Button(
                body,
                text="✕  Kapatmayı İptal Et (Vazgeç)",
                font=("Segoe UI", 11, "bold"),
                bg="#334155",
                fg=fg_white,
                activebackground="#475569",
                activeforeground=fg_white,
                relief=tk.FLAT,
                padx=16,
                pady=8,
                cursor="hand2",
                command=self._handle_user_cancel,
            )
            cancel_btn.pack(fill=tk.X)
            self.root.protocol("WM_DELETE_WINDOW", self._handle_user_cancel)
        else:
            lock_frame = tk.Frame(body, bg="#1E293B", padx=8, pady=8)
            lock_frame.pack(fill=tk.X)
            lock_lbl = tk.Label(
                lock_frame,
                text="🔒 Bu kapatma emri yalnızca telefondan iptal edilebilir.",
                font=("Segoe UI", 9, "bold"),
                bg="#1E293B",
                fg="#FBBF24",
                wraplength=360,
            )
            lock_lbl.pack()
            # Bilgisayardan kapatma penceresinin çarpı tuşuyla kapatılmasını engelle
            self.root.protocol("WM_DELETE_WINDOW", lambda: None)

        # Geri sayım döngüsü
        self._timer_running = True
        self._tick()

        self.root.mainloop()

    def _format_time(self, seconds: int) -> str:
        mins, secs = divmod(seconds, 60)
        hours, mins = divmod(mins, 60)
        if hours > 0:
            return f"{hours:02d}:{mins:02d}:{secs:02d}"
        return f"{mins:02d}:{secs:02d}"

    def _tick(self):
        if not self._timer_running or not self.root:
            return

        if self.remaining_seconds <= 0:
            self._timer_running = False
            self.countdown_lbl.configure(text="00:00")
            if self.on_timeout:
                self.on_timeout()
            self._destroy_window()
            return

        self.countdown_lbl.configure(text=self._format_time(self.remaining_seconds))
        self.remaining_seconds -= 1
        self.root.after(1000, self._tick)

    def _handle_user_cancel(self):
        """Kullanıcı PC başındayken İptal Et butonuna bastığında."""
        self._timer_running = False
        self.is_active = False
        if self.on_cancel:
            self.on_cancel()
        self._destroy_window()
