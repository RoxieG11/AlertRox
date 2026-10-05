"""
AlertRox — PC Canlı Chat Penceresi (Tkinter)

Telefondan mesaj geldiğinde veya sohbet başlatıldığında
ekranın sağ altında beliren hafif ve modern sohbet penceresi.
Kullanıcı kapatırsa telefondan tekrar açılabilir.
"""

import os
import threading
import time
import tkinter as tk
from tkinter import ttk
from datetime import datetime


class AlertRoxChatWindow:
    """PC tarafında masaüstünde çalışan iki yönlü chat penceresi."""

    def __init__(self, client):
        self.client = client
        self.root = None
        self.is_open = False
        self.message_list = []
        self._thread = None
        self._poll_running = False

    def launch(self):
        """Chat penceresini başlatır (eğer açık değilse açar, açıksa öne getirir)."""
        if self.is_open and self.root:
            self.root.after(0, self._bring_to_front)
            return

        self._thread = threading.Thread(target=self._run_gui, daemon=True)
        self._thread.start()

    def _bring_to_front(self):
        if self.root:
            self.root.deiconify()
            self.root.attributes("-topmost", True)
            self.root.attributes("-topmost", False)
            self.root.focus_force()

    def _run_gui(self):
        self.root = tk.Tk()
        self.root.title("AlertRox — Güvenli Sohbet")
        self.root.geometry("380x520")
        self.root.minsize(340, 440)
        self.is_open = True

        # Pencereyi sağ alta konumlandır
        self.root.update_idletasks()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        self.root.geometry(f"380x520+{sw - 410}+{sh - 580}")

        # Karanlık Tema Renkleri
        bg_dark = "#18181b"
        bg_card = "#27272a"
        fg_white = "#f4f4f5"
        accent_blue = "#3b82f6"
        accent_green = "#22c55e"
        gray_muted = "#71717a"

        self.root.configure(bg=bg_dark)

        # ── Başlık Barı ──
        header = tk.Frame(self.root, bg=bg_card, height=54)
        header.pack(fill=tk.X)

        title_lbl = tk.Label(
            header,
            text="📱 AlertRox Telefon Bağlantısı",
            font=("Segoe UI", 11, "bold"),
            bg=bg_card,
            fg=fg_white,
            padx=14,
            pady=12,
        )
        title_lbl.pack(side=tk.LEFT)

        status_lbl = tk.Label(
            header,
            text="● Canlı",
            font=("Segoe UI", 9, "bold"),
            bg=bg_card,
            fg=accent_green,
            padx=14,
        )
        status_lbl.pack(side=tk.RIGHT)

        # ── Mesaj Alanı ──
        msg_frame = tk.Frame(self.root, bg=bg_dark, padx=10, pady=10)
        msg_frame.pack(fill=tk.BOTH, expand=True)

        self.chat_display = tk.Text(
            msg_frame,
            bg="#202024",
            fg=fg_white,
            font=("Segoe UI", 10),
            wrap=tk.WORD,
            padx=12,
            pady=10,
            relief=tk.FLAT,
            state=tk.DISABLED,
            cursor="arrow",
        )
        self.chat_display.pack(fill=tk.BOTH, expand=True)

        # Mesaj tag stilleri
        self.chat_display.tag_config("mobile_header", foreground=accent_blue, font=("Segoe UI", 9, "bold"))
        self.chat_display.tag_config("pc_header", foreground=accent_green, font=("Segoe UI", 9, "bold"))
        self.chat_display.tag_config("mobile_msg", foreground="#e4e4e7", spacing1=2, spacing3=8)
        self.chat_display.tag_config("pc_msg", foreground="#e4e4e7", spacing1=2, spacing3=8)
        self.chat_display.tag_config("time", foreground=gray_muted, font=("Segoe UI", 8))

        # ── Giriş Alanı ──
        input_frame = tk.Frame(self.root, bg=bg_card, padx=10, pady=10)
        input_frame.pack(fill=tk.X)

        self.entry_msg = tk.Entry(
            input_frame,
            bg="#18181b",
            fg=fg_white,
            insertbackground=fg_white,
            font=("Segoe UI", 10),
            relief=tk.FLAT,
        )
        self.entry_msg.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=7, padx=(0, 8))
        self.entry_msg.bind("<Return>", lambda e: self.send_message())
        self.entry_msg.focus()

        send_btn = tk.Button(
            input_frame,
            text="Gönder",
            bg=accent_blue,
            fg="white",
            activebackground="#2563eb",
            activeforeground="white",
            font=("Segoe UI", 10, "bold"),
            relief=tk.FLAT,
            padx=14,
            command=self.send_message,
        )
        send_btn.pack(side=tk.RIGHT)

        # Pencere kapatılınca
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

        # Mesaj dinleme döngüsünü başlat
        self._poll_running = True
        threading.Thread(target=self._poll_messages, daemon=True).start()

        self._bring_to_front()
        self.root.mainloop()

    def _on_close(self):
        """Kapatılınca tamamen yok etme, gizle veya tekrar açılabilir yap."""
        self.is_open = False
        self._poll_running = False
        if self.root:
            try:
                self.root.destroy()
            except Exception:
                pass
            self.root = None

    def send_message(self):
        """PC'den telefona mesaj gönderir."""
        text = self.entry_msg.get().strip()
        if not text:
            return

        self.entry_msg.delete(0, tk.END)

        # Ekrana bas
        now = datetime.now().strftime("%H:%M")
        self._append_message("PC (Siz)", text, now, is_mobile=False)

        # Supabase'e gönder
        threading.Thread(
            target=self._send_to_supabase,
            args=(text,),
            daemon=True,
        ).start()

    def _send_to_supabase(self, text: str):
        try:
            self.client.send_chat_message(sender="pc", text=text)
        except Exception as e:
            print(f"[AlertRox Chat] Mesaj gönderme hatası: {e}")

    def _append_message(self, sender_name: str, text: str, time_str: str, is_mobile: bool):
        if not self.root:
            return

        def _insert():
            self.chat_display.configure(state=tk.NORMAL)
            hdr_tag = "mobile_header" if is_mobile else "pc_header"
            msg_tag = "mobile_msg" if is_mobile else "pc_msg"

            self.chat_display.insert(tk.END, f"{sender_name} ", hdr_tag)
            self.chat_display.insert(tk.END, f"({time_str})\n", "time")
            self.chat_display.insert(tk.END, f"{text}\n\n", msg_tag)
            self.chat_display.configure(state=tk.DISABLED)
            self.chat_display.see(tk.END)

        self.root.after(0, _insert)

    def _poll_messages(self):
        """Supabase'den telefondan gelen yeni mesajları çeker."""
        seen_ids = set()

        # İlk açılışta eski mesajları çek
        try:
            old_msgs = self.client.get_chat_messages(limit=20)
            for m in old_msgs:
                seen_ids.add(m["id"])
                time_str = m.get("created_at", "")[11:16] if m.get("created_at") else ""
                is_mob = m.get("sender") == "mobile"
                sender = "📱 Telefon" if is_mob else "PC (Siz)"
                self._append_message(sender, m.get("text", ""), time_str, is_mob)
        except Exception as e:
            print(f"[AlertRox Chat] Geçmiş mesaj hatası: {e}")

        while self._poll_running:
            time.sleep(2)
            if not self.is_open or not self.client:
                continue

            try:
                new_msgs = self.client.get_chat_messages(limit=10)
                for m in new_msgs:
                    mid = m["id"]
                    if mid not in seen_ids:
                        seen_ids.add(mid)
                        is_mob = m.get("sender") == "mobile"
                        time_str = m.get("created_at", "")[11:16] if m.get("created_at") else ""
                        sender = "📱 Telefon" if is_mob else "PC"
                        self._append_message(sender, m.get("text", ""), time_str, is_mob)
                        if is_mob:
                            self._bring_to_front()
            except Exception:
                pass
