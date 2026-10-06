"""
AlertRox — PC Canlı Chat Penceresi (Modern Tkinter)

Telefondan mesaj geldiğinde veya sohbet başlatıldığında
ekranın sağ altında beliren hafif, modern ve neon tasarımlı sohbet penceresi.
Telefondan veya PC'den temizleme yapıldığında her iki tarafta anlık senkronize olur.
"""

import os
import threading
import time
import tkinter as tk
from tkinter import messagebox
from datetime import datetime


class AlertRoxChatWindow:
    """PC tarafında masaüstünde çalışan iki yönlü modern chat penceresi."""

    def __init__(self, client):
        self.client = client
        self.root = None
        self.is_open = False
        self._thread = None
        self._poll_running = False
        self._seen_ids = set()

    def launch(self):
        """Chat penceresini başlatır (eğer açık değilse açar, açıksa öne getirir)."""
        if self.root:
            try:
                self.is_open = True
                self.root.after(0, self._bring_to_front)
                return
            except Exception:
                pass

        if not self._thread or not self._thread.is_alive():
            self._thread = threading.Thread(target=self._run_gui, daemon=True)
            self._thread.start()

    def _bring_to_front(self):
        if self.root:
            try:
                self.root.deiconify()
                self.root.lift()
                self.root.attributes("-topmost", True)
                self.root.attributes("-topmost", False)
                self.root.focus_force()
            except Exception:
                pass

    def _run_gui(self):
        try:
            if "DISPLAY" not in os.environ and "WAYLAND_DISPLAY" not in os.environ:
                os.environ["DISPLAY"] = ":0"
            self.root = tk.Tk()
        except Exception as e:
            print(f"[AlertRox Chat] GUI başlatma hatası: {e}")
            self.is_open = False
            return

        self.root.title("AlertRox — Canlı Sohbet")
        self.root.geometry("400x560")
        self.root.minsize(360, 480)
        self.is_open = True

        # Renk Paleti (AlertRox Koyu Neon)
        bg_dark = "#0B0F19"
        bg_card = "#161F30"
        bg_input = "#0F172A"
        accent_teal = "#00F0FF"
        accent_green = "#10B981"
        fg_white = "#F8FAFC"
        fg_muted = "#94A3B8"
        border_col = "#1E293B"

        self.root.configure(bg=bg_dark)

        # Pencereyi sağ alta konumlandır
        self.root.update_idletasks()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        self.root.geometry(f"400x560+{sw - 430}+{sh - 620}")

        # ── Başlık Barı ──
        header = tk.Frame(self.root, bg=bg_card, height=54, padx=12, pady=10)
        header.pack(fill=tk.X)

        title_frame = tk.Frame(header, bg=bg_card)
        title_frame.pack(side=tk.LEFT, fill=tk.Y)

        title_lbl = tk.Label(
            title_frame,
            text="📱 AlertRox Sohbet",
            font=("Segoe UI", 11, "bold"),
            bg=bg_card,
            fg=fg_white,
        )
        title_lbl.pack(anchor="w")

        status_lbl = tk.Label(
            title_frame,
            text="● Çevrimiçi & Canlı Senkronize",
            font=("Segoe UI", 8),
            bg=bg_card,
            fg=accent_green,
        )
        status_lbl.pack(anchor="w")

        # Sohbeti Temizle Butonu
        clear_btn = tk.Button(
            header,
            text="🗑 Temizle",
            font=("Segoe UI", 9, "bold"),
            bg="#27272A",
            fg="#EF4444",
            activebackground="#EF4444",
            activeforeground="white",
            relief=tk.FLAT,
            padx=10,
            pady=4,
            cursor="hand2",
            command=self._confirm_clear_chat,
        )
        clear_btn.pack(side=tk.RIGHT)

        # ── Mesaj Alanı ──
        msg_container = tk.Frame(self.root, bg=bg_dark, padx=12, pady=10)
        msg_container.pack(fill=tk.BOTH, expand=True)

        self.chat_display = tk.Text(
            msg_container,
            bg="#0E1626",
            fg=fg_white,
            font=("Segoe UI", 10),
            wrap=tk.WORD,
            padx=14,
            pady=12,
            relief=tk.FLAT,
            state=tk.DISABLED,
            cursor="arrow",
            highlightthickness=1,
            highlightbackground=border_col,
            highlightcolor=accent_teal,
        )
        self.chat_display.pack(fill=tk.BOTH, expand=True)

        # Tag Stilleri (Modern Görünüm)
        self.chat_display.tag_config(
            "mobile_sender",
            foreground=accent_teal,
            font=("Segoe UI", 9, "bold"),
            spacing1=8,
        )
        self.chat_display.tag_config(
            "pc_sender",
            foreground=accent_green,
            font=("Segoe UI", 9, "bold"),
            spacing1=8,
        )
        self.chat_display.tag_config(
            "mobile_bubble",
            foreground="#E2E8F0",
            spacing1=2,
            spacing3=6,
            lmargin1=8,
            lmargin2=8,
        )
        self.chat_display.tag_config(
            "pc_bubble",
            foreground="#F1F5F9",
            spacing1=2,
            spacing3=6,
            lmargin1=8,
            lmargin2=8,
        )
        self.chat_display.tag_config("time", foreground=fg_muted, font=("Segoe UI", 8))

        # ── Giriş Alanı ──
        input_container = tk.Frame(self.root, bg=bg_card, padx=12, pady=12)
        input_container.pack(fill=tk.X)

        self.entry_msg = tk.Entry(
            input_container,
            bg=bg_input,
            fg=fg_white,
            insertbackground=accent_teal,
            font=("Segoe UI", 10),
            relief=tk.FLAT,
            highlightthickness=1,
            highlightbackground=border_col,
            highlightcolor=accent_teal,
        )
        self.entry_msg.pack(side=tk.LEFT, fill=tk.X, expand=True, ipady=8, padx=(0, 10))
        self.entry_msg.bind("<Return>", lambda e: self.send_message())
        self.entry_msg.focus()

        send_btn = tk.Button(
            input_container,
            text="Gönder",
            bg=accent_teal,
            fg="#0B0F19",
            activebackground="#38BDF8",
            activeforeground="#0B0F19",
            font=("Segoe UI", 10, "bold"),
            relief=tk.FLAT,
            padx=16,
            pady=6,
            cursor="hand2",
            command=self.send_message,
        )
        send_btn.pack(side=tk.RIGHT)

        # Geçmiş mesajları yükle
        try:
            initial_msgs = self.client.get_chat_messages(limit=40)
            for m in initial_msgs:
                self._seen_ids.add(m["id"])
                is_mob = m.get("sender") == "mobile"
                time_str = m.get("created_at", "")[11:16] if m.get("created_at") else ""
                sender = "📱 Telefon" if is_mob else "💻 PC (Siz)"
                self._append_message(sender, m.get("text", ""), time_str, is_mob)
        except Exception:
            pass

        # Pencere kapatılınca
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

        # Mesaj dinleme döngüsünü başlat (eğer henüz başlamadıysa)
        if not self._poll_running:
            self._poll_running = True
            threading.Thread(target=self._poll_messages, daemon=True).start()

        self._bring_to_front()
        self.root.mainloop()

    def start_background_listener(self):
        """Uygulama açılışında arka planda mesaj dinleyicisini başlatır."""
        if not self._poll_running:
            self._poll_running = True
            threading.Thread(target=self._poll_messages, daemon=True).start()

    def _on_close(self):
        """Pencere kapatıldığında yok etmek yerine gizler (withdraw). Böylece yeniden açılması anında ve hatasız olur."""
        self.is_open = False
        if self.root:
            try:
                self.root.withdraw()
            except Exception:
                pass

    def _confirm_clear_chat(self):
        """PC'den sohbeti temizleme onayı."""
        ans = messagebox.askyesno(
            "Sohbeti Temizle",
            "Tüm sohbet geçmişini silmek istediğinize emin misiniz?\nBu işlem telefondan da mesajları silecektir.",
            parent=self.root,
        )
        if ans:
            threading.Thread(target=self._clear_chat_supabase, daemon=True).start()

    def _clear_chat_supabase(self):
        try:
            self.client.clear_chat_messages()
            self._clear_display()
            self._seen_ids.clear()
        except Exception as e:
            print(f"[AlertRox Chat] Sohbet silme hatası: {e}")

    def _clear_display(self):
        if not self.root:
            return

        def _do_clear():
            self.chat_display.configure(state=tk.NORMAL)
            self.chat_display.delete("1.0", tk.END)
            self.chat_display.configure(state=tk.DISABLED)

        self.root.after(0, _do_clear)

    def send_message(self):
        """PC'den telefona mesaj gönderir."""
        text = self.entry_msg.get().strip()
        if not text:
            return

        self.entry_msg.delete(0, tk.END)

        # Supabase'e gönder
        threading.Thread(
            target=self._send_to_supabase,
            args=(text,),
            daemon=True,
        ).start()

    def _send_to_supabase(self, text: str):
        try:
            res = self.client.send_chat_message(sender="pc", text=text)
            if res and "id" in res:
                self._seen_ids.add(res["id"])
                now = datetime.now().strftime("%H:%M")
                self._append_message("💻 PC (Siz)", text, now, is_mobile=False)
        except Exception as e:
            print(f"[AlertRox Chat] Mesaj gönderme hatası: {e}")

    def _append_message(self, sender_name: str, text: str, time_str: str, is_mobile: bool):
        if not self.root:
            return

        def _insert():
            self.chat_display.configure(state=tk.NORMAL)
            hdr_tag = "mobile_sender" if is_mobile else "pc_sender"
            bubble_tag = "mobile_bubble" if is_mobile else "pc_bubble"

            self.chat_display.insert(tk.END, f"{sender_name} ", hdr_tag)
            self.chat_display.insert(tk.END, f"({time_str})\n", "time")
            self.chat_display.insert(tk.END, f"{text}\n\n", bubble_tag)
            self.chat_display.configure(state=tk.DISABLED)
            self.chat_display.see(tk.END)

        self.root.after(0, _insert)

    def _poll_messages(self):
        """Supabase'den mesajları çeker ve telefondan mesaj geldiğinde pencereyi öne getirir."""
        while self._poll_running:
            try:
                if not self.client:
                    time.sleep(2)
                    continue

                messages = self.client.get_chat_messages(limit=40)
                current_ids = {m["id"] for m in messages}

                # 1. Telefondan veya dışarıdan temizleme yapıldıysa (mesajlar silindiyse)
                if self._seen_ids and not current_ids:
                    self._clear_display()
                    self._seen_ids.clear()
                elif self._seen_ids and not self._seen_ids.issubset(current_ids):
                    # Bazı mesajlar silinmişse ekranı yeniden çiz
                    self._clear_display()
                    self._seen_ids.clear()
                    for m in messages:
                        self._seen_ids.add(m["id"])
                        is_mob = m.get("sender") == "mobile"
                        time_str = m.get("created_at", "")[11:16] if m.get("created_at") else ""
                        sender = "📱 Telefon" if is_mob else "💻 PC (Siz)"
                        self._append_message(sender, m.get("text", ""), time_str, is_mob)
                else:
                    # 2. Yeni gelen mesajları ekle
                    for m in messages:
                        mid = m["id"]
                        if mid not in self._seen_ids:
                            self._seen_ids.add(mid)
                            is_mob = m.get("sender") == "mobile"
                            time_str = m.get("created_at", "")[11:16] if m.get("created_at") else ""
                            sender = "📱 Telefon" if is_mob else "💻 PC (Siz)"
                            self._append_message(sender, m.get("text", ""), time_str, is_mob)
                            if is_mob:
                                self.launch()
            except Exception as e:
                pass

            time.sleep(1.5)
