"""
AlertRox — Çoklu Dil Yöneticisi (i18n)

JSON tabanlı basit çeviri sistemi.
Yeni dil eklemek = locales/ klasörüne yeni .json dosyası eklemek kadar kolay.

Kullanım:
    from i18n import I18n

    i18n = I18n("tr")              # Türkçe başlat
    print(i18n.t("btn_shutdown"))   # "Bilgisayarı Kapat"

    i18n.set_language("en")         # İngilizce'ye geç
    print(i18n.t("btn_shutdown"))   # "Shutdown PC"
"""

import os
import json


class I18n:
    """Çoklu dil yönetici sınıfı."""

    # Desteklenen diller ve görünen adları
    LANGUAGES = {
        "tr": "🇹🇷 Türkçe",
        "en": "🇬🇧 English",
    }

    def __init__(self, default_lang: str = "tr"):
        self.locales_dir = os.path.join(os.path.dirname(__file__), "locales")
        self.current_lang = default_lang
        self.translations: dict = {}
        self._load_language(default_lang)

    def _load_language(self, lang: str) -> None:
        """Dil dosyasını yükle."""
        file_path = os.path.join(self.locales_dir, f"{lang}.json")

        if not os.path.exists(file_path):
            print(f"[i18n] Uyarı: '{lang}' dil dosyası bulunamadı, 'tr' kullanılıyor")
            file_path = os.path.join(self.locales_dir, "tr.json")
            self.current_lang = "tr"

        with open(file_path, "r", encoding="utf-8") as f:
            self.translations = json.load(f)

    def t(self, key: str, **kwargs) -> str:
        """
        Çeviri al. Anahtar bulunamazsa anahtar adını döndürür.

        Parametreli kullanım:
            i18n.t("msg_hello", name="Roxie")  → "Merhaba Roxie!"
            (JSON'da: "msg_hello": "Merhaba {name}!")
        """
        text = self.translations.get(key, key)
        if kwargs:
            try:
                text = text.format(**kwargs)
            except (KeyError, ValueError):
                pass
        return text

    def set_language(self, lang: str) -> None:
        """Dili değiştir."""
        self.current_lang = lang
        self._load_language(lang)

    def get_available_languages(self) -> dict:
        """Mevcut dilleri döndür."""
        available = {}
        for code, name in self.LANGUAGES.items():
            file_path = os.path.join(self.locales_dir, f"{code}.json")
            if os.path.exists(file_path):
                available[code] = name
        return available
