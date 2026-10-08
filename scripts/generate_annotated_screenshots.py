#!/usr/bin/env python3
"""
AlertRox — Otomatik Ekran Görüntüsü Düzenleyici, Sansürleyici ve Çok Dilli Görsel Üretici
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW_DIR = "/home/roxie/.gemini/antigravity/brain/cd52aedc-4d61-443b-b52d-2febdb1b9cff/.user_uploaded"
OUT_BASE = "assets/screenshots"

RAW_FILES = {
    'dashboard': os.path.join(RAW_DIR, 'media_1791430183458.jpg'),
    'apps': os.path.join(RAW_DIR, 'media_1791430183465.jpg'),
    'media': os.path.join(RAW_DIR, 'media_1791430183472.jpg'),
    'volume': os.path.join(RAW_DIR, 'media_1791430183489.jpg'),
    'widget': os.path.join(RAW_DIR, 'media_1791430183494.jpg'),
    'supabase': os.path.join(RAW_DIR, 'media_1791430375931.png'),
}

LANGUAGES = ['tr', 'en', 'de', 'ru', 'es', 'ar', 'fr', 'pt', 'zh', 'ja']

ANNOTATIONS = {
    'dashboard': {
        'status': {
            'en': 'Live PC Status (Online / Battery / IP)',
            'de': 'Live PC-Status (Online / Akku / IP)',
            'ru': 'Статус ПК (В сети / Батарея / IP)',
            'es': 'Estado de la PC (En línea / Batería / IP)',
            'ar': 'حالة الكمبيوتر المباشرة (متصل / البطارية)',
            'fr': 'Statut du PC en direct (En ligne / Batterie / IP)',
            'pt': 'Status do PC em tempo real (Online / Bateria / IP)',
            'zh': '实时电脑状态（在线 / 电量 / IP）',
            'ja': 'リアルタイムPC状態（オンライン / バッテリー / IP）',
        },
        'actions': {
            'en': 'Quick Action Controls (Lock, Shutdown etc.)',
            'de': 'Schnellaktionen (Sperren, Herunterfahren etc.)',
            'ru': 'Быстрые действия (Блокировка, Выключение и др.)',
            'es': 'Controles rápidos (Bloquear, Apagar, etc.)',
            'ar': 'إجراءات سريعة (قفل، إيقاف التشغيل إلخ)',
            'fr': 'Contrôles rapides (Verrouiller, Éteindre etc.)',
            'pt': 'Controles rápidos (Bloquear, Desligar etc.)',
            'zh': '快捷操作（锁定、关机等）',
            'ja': 'クイック操作（ロック、シャットダウン等）',
        },
    },
    'apps': {
        'tabs': {
            'en': 'Running & Installed Desktop Apps',
            'de': 'Laufende & Installierte Anwendungen',
            'ru': 'Запущенные и установленные приложения',
            'es': 'Aplicaciones abiertas e instaladas',
            'ar': 'التطبيقات المشغلة والمثبتة',
            'fr': 'Applications en cours et installées',
            'pt': 'Aplicativos em execução e instalados',
            'zh': '运行中与已安装的应用',
            'ja': '実行中およびインストール済みアプリ',
        },
        'launch': {
            'en': 'One-Click Launch & Close on PC',
            'de': 'Ein-Klick Starten & Beenden auf dem PC',
            'ru': 'Запуск и закрытие на ПК в один клик',
            'es': 'Iniciar y cerrar en la PC con un toque',
            'ar': 'تشغيل وإغلاق بنقرة واحدة على الكمبيوتر',
            'fr': 'Lancer et fermer sur PC en un clic',
            'pt': 'Iniciar e fechar no PC com um toque',
            'zh': '一键在电脑上启动或关闭',
            'ja': 'PC上でワンクリック起動 / 終了',
        },
    },
    'media': {
        'audio': {
            'en': 'In-App Audio Player (Listen without download)',
            'de': 'In-App Audio-Player (Ohne Download anhören)',
            'ru': 'Встроенный аудиоплеер (Без скачивания)',
            'es': 'Reproductor de audio (Escucha sin descargar)',
            'ar': 'مشغل صوت مدمج (استماع بدون تنزيل)',
            'fr': 'Lecteur audio intégré (Écouter sans télécharger)',
            'pt': 'Player de áudio no app (Ouvir sem baixar)',
            'zh': '应用内音频播放器（无需下载直接收听）',
            'ja': 'アプリ内オーディオプレーヤー（ダウンロード不要）',
        },
        'preview': {
            'en': 'Screenshot & Webcam Preview / Download',
            'de': 'Screenshot- & Webcam-Vorschau / Download',
            'ru': 'Просмотр и скачивание скриншота/веб-камеры',
            'es': 'Vista previa y descarga de capturas y cámara',
            'ar': 'معاينة وتنزيل لقطة الشاشة والكاميرا',
            'fr': 'Aperçu et téléchargement de la capture et webcam',
            'pt': 'Prévia e download de captura de tela e webcam',
            'zh': '屏幕截图与摄像头预览及下载',
            'ja': 'スクリーンショット＆Webカメラプレビュー/保存',
        },
    },
    'volume': {
        'slider': {
            'en': 'Realtime PC Volume & Media Controls',
            'de': 'Echtzeit-PC-Lautstärke & Mediensteuerung',
            'ru': 'Громкость ПК и управление медиа в реальном времени',
            'es': 'Volumen de PC y controles de medios en tiempo real',
            'ar': 'التحكم في صوت الكمبيوتر والوسائط المباشرة',
            'fr': 'Volume PC et contrôles multimédias en temps réel',
            'pt': 'Volume do PC e controles de mídia em tempo real',
            'zh': '实时电脑音量与媒体控制',
            'ja': 'リアルタイムPC音量＆メディアコントロール',
        },
    },
    'widget': {
        'widget': {
            'en': 'Live Android Home Screen Widget (PC Status)',
            'de': 'Live Android Startbildschirm-Widget (PC-Status)',
            'ru': 'Виджет главного экрана Android (Статус ПК)',
            'es': 'Widget de pantalla de inicio de Android (Estado)',
            'ar': 'ودجت الشاشة الرئيسية لنظام أندرويد (حالة الكمبيوتر)',
            'fr': "Widget d'écran d'accueil Android (Statut PC)",
            'pt': 'Widget de tela inicial do Android (Status do PC)',
            'zh': '安卓桌面实时小组件（实时状态）',
            'ja': 'Androidホーム画面リアルタイムウィジェット',
        },
    },
    'supabase': {
        'step1': {
            'en': '1. Paste "supabase_schema.sql" code here',
            'de': '1. Fügen Sie "supabase_schema.sql" hier ein',
            'ru': '1. Вставьте код "supabase_schema.sql" сюда',
            'es': '1. Pega el código de "supabase_schema.sql" aquí',
            'ar': '1. الصق كود "supabase_schema.sql" هنا',
            'fr': '1. Collez le code "supabase_schema.sql" ici',
            'pt': '1. Cole o código "supabase_schema.sql" aqui',
            'zh': '1. 将 "supabase_schema.sql" 代码粘贴在此处',
            'ja': '1. ここに "supabase_schema.sql" コードを貼り付けます',
        },
        'step2': {
            'en': '2. Click "Run" to execute',
            'de': '2. Auf "Run" (Ausführen) klicken',
            'ru': '2. Нажмите "Run" для выполнения',
            'es': '2. Haz clic en "Run" para ejecutar',
            'ar': '2. انقر فوق "Run" للتشغيل',
            'fr': '2. Cliquez sur "Run" pour exécuter',
            'pt': '2. Clique em "Run" para executar',
            'zh': '2. 点击 "Run" 执行',
            'ja': '2. "Run"（実行）をクリックします',
        },
    },
}

def get_font(size, lang='en'):
    if lang in ['zh', 'ja']:
        font_path = '/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc'
    elif lang == 'ar':
        font_path = '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
    else:
        font_path = '/usr/share/fonts/noto/NotoSans-Regular.ttf'
    try:
        return ImageFont.truetype(font_path, size)
    except Exception:
        return ImageFont.load_default()

def draw_pill_badge(draw, x, y, text, font, border_color=(0, 240, 255), bg_color=(15, 23, 42, 235), text_color=(255, 255, 255), pad_x=12, pad_y=5, dot_color=None):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    dot_space = 14 if dot_color else 0
    w = tw + pad_x * 2 + dot_space
    h = th + pad_y * 2
    
    # Draw rounded rect
    draw.rounded_rectangle([x, y, x + w, y + h], radius=6, fill=bg_color, outline=border_color, width=2)
    
    # Optional indicator dot
    if dot_color:
        dot_r = 4
        dot_cy = y + h // 2
        dot_cx = x + pad_x + dot_r
        draw.ellipse([dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r], fill=dot_color)
    
    draw.text((x + pad_x + dot_space, y + pad_y - bbox[1] + 1), text, fill=text_color, font=font)
    return (x, y, w, h)

def draw_callout_arrow(draw, start_pt, end_pt, color=(0, 240, 255), width=2):
    draw.line([start_pt, end_pt], fill=color, width=width)
    dx = end_pt[0] - start_pt[0]
    dy = end_pt[1] - start_pt[1]
    angle = math.atan2(dy, dx)
    head_len = 9
    head_angle = math.pi / 6
    p1 = end_pt
    p2 = (end_pt[0] - head_len * math.cos(angle - head_angle),
          end_pt[1] - head_len * math.sin(angle - head_angle))
    p3 = (end_pt[0] - head_len * math.cos(angle + head_angle),
          end_pt[1] - head_len * math.sin(angle + head_angle))
    draw.polygon([p1, p2, p3], fill=color)

def censor_region(img, box, blur_radius=10, fill_color=(20, 20, 30)):
    cropped = img.crop(box)
    blurred = cropped.filter(ImageFilter.GaussianBlur(blur_radius))
    img.paste(blurred, box)
    draw = ImageDraw.Draw(img, 'RGBA')
    draw.rounded_rectangle(box, radius=4, fill=(fill_color[0], fill_color[1], fill_color[2], 190))

def process_dashboard(lang):
    im = Image.open(RAW_FILES['dashboard']).convert('RGBA')
    # Censor IP: (75, 260, 175, 285)
    censor_region(im, (75, 260, 175, 285), blur_radius=8)
    
    if lang == 'tr':
        return im  # Turkish: Pure clean screenshot with censorship only!
    
    draw = ImageDraw.Draw(im)
    font = get_font(12, lang)
    
    # Status Card Callout Badge
    txt_status = ANNOTATIONS['dashboard']['status'][lang]
    draw_pill_badge(draw, 30, 105, txt_status, font, border_color=(0, 240, 255), dot_color=(0, 240, 255))
    
    # Action Cards Callout Badge
    txt_actions = ANNOTATIONS['dashboard']['actions'][lang]
    draw_pill_badge(draw, 30, 345, txt_actions, font, border_color=(16, 185, 129), dot_color=(16, 185, 129))
    
    return im

def process_apps(lang):
    im = Image.open(RAW_FILES['apps']).convert('RGBA')
    # Censor local user path in Albion: (100, 592, 280, 615)
    censor_region(im, (100, 592, 280, 615), blur_radius=6)
    
    if lang == 'tr':
        return im  # Turkish: Pure clean screenshot with censorship only!
    
    draw = ImageDraw.Draw(im)
    font = get_font(12, lang)
    
    # Tabs Callout Badge
    txt_tabs = ANNOTATIONS['apps']['tabs'][lang]
    draw_pill_badge(draw, 30, 95, txt_tabs, font, border_color=(0, 240, 255), dot_color=(0, 240, 255))
    
    # Launch button Callout Badge & Arrow
    txt_launch = ANNOTATIONS['apps']['launch'][lang]
    b_launch = draw_pill_badge(draw, 45, 235, txt_launch, font, border_color=(16, 185, 129), dot_color=(16, 185, 129))
    draw_callout_arrow(draw, (b_launch[0] + b_launch[2] + 4, b_launch[1] + b_launch[3] // 2), (320, 280), color=(16, 185, 129), width=2)
    
    return im

def process_media(lang):
    im = Image.open(RAW_FILES['media']).convert('RGBA')
    
    if lang == 'tr':
        return im  # Turkish: Pure clean screenshot!
    
    draw = ImageDraw.Draw(im)
    font = get_font(12, lang)
    
    # Audio Player Badge
    txt_audio = ANNOTATIONS['media']['audio'][lang]
    draw_pill_badge(draw, 30, 110, txt_audio, font, border_color=(0, 240, 255), dot_color=(0, 240, 255))
    
    # Screenshot Card Badge
    txt_prev = ANNOTATIONS['media']['preview'][lang]
    draw_pill_badge(draw, 30, 350, txt_prev, font, border_color=(16, 185, 129), dot_color=(16, 185, 129))
    
    return im

def process_volume(lang):
    im = Image.open(RAW_FILES['volume']).convert('RGBA')
    
    if lang == 'tr':
        return im  # Turkish: Pure clean screenshot!
    
    draw = ImageDraw.Draw(im)
    font = get_font(12, lang)
    
    # Badge placed neatly above the sheet at (25, 636)
    txt_vol = ANNOTATIONS['volume']['slider'][lang]
    draw_pill_badge(draw, 25, 636, txt_vol, font, border_color=(0, 240, 255), dot_color=(0, 240, 255))
    
    return im

def process_widget(lang):
    im = Image.open(RAW_FILES['widget']).convert('RGBA')
    
    if lang == 'tr':
        return im  # Turkish: Pure clean screenshot!
    
    draw = ImageDraw.Draw(im)
    font = get_font(12, lang)
    
    # Widget Badge
    txt_widget = ANNOTATIONS['widget']['widget'][lang]
    draw_pill_badge(draw, 35, 70, txt_widget, font, border_color=(0, 240, 255), dot_color=(0, 240, 255))
    
    return im

def process_supabase(lang):
    im = Image.open(RAW_FILES['supabase']).convert('RGBA')
    # Censor breadcrumb 'Roxie FREE': (55, 10, 140, 33)
    censor_region(im, (55, 10, 140, 33), blur_radius=8, fill_color=(15, 23, 42))
    # Censor avatar top right: (990, 8, 1015, 33)
    censor_region(im, (990, 8, 1015, 33), blur_radius=8, fill_color=(15, 23, 42))
    
    if lang == 'tr':
        return im  # Turkish: Clean screenshot with censorship only!
    
    draw = ImageDraw.Draw(im)
    font = get_font(13, lang)
    
    # Step 1: SQL Editor Query Area Badge
    txt_step1 = ANNOTATIONS['supabase']['step1'][lang]
    draw_pill_badge(draw, 185, 110, txt_step1, font, border_color=(0, 240, 255), pad_x=12, pad_y=6, dot_color=(0, 240, 255))
    
    # Step 2: Run Button Badge & Arrow pointing to Run button
    txt_step2 = ANNOTATIONS['supabase']['step2'][lang]
    b2 = draw_pill_badge(draw, 680, 52, txt_step2, font, border_color=(16, 185, 129), pad_x=12, pad_y=6, dot_color=(16, 185, 129))
    draw_callout_arrow(draw, (b2[0] + b2[2] + 4, b2[1] + b2[3] // 2), (940, 66), color=(16, 185, 129), width=2)
    
    return im

def main():
    print("🎨 Generating updated screenshots across all 10 languages...")
    
    for lang in LANGUAGES:
        out_dir = os.path.join(OUT_BASE, lang)
        os.makedirs(out_dir, exist_ok=True)
        
        # 1. Dashboard
        im_dash = process_dashboard(lang)
        im_dash.convert('RGB').save(os.path.join(out_dir, 'dashboard.png'), optimize=True)
        
        # 2. Apps
        im_apps = process_apps(lang)
        im_apps.convert('RGB').save(os.path.join(out_dir, 'apps.png'), optimize=True)
        
        # 3. Media
        im_media = process_media(lang)
        im_media.convert('RGB').save(os.path.join(out_dir, 'media.png'), optimize=True)
        
        # 4. Volume
        im_volume = process_volume(lang)
        im_volume.convert('RGB').save(os.path.join(out_dir, 'volume.png'), optimize=True)
        
        # 5. Widget
        im_widget = process_widget(lang)
        im_widget.convert('RGB').save(os.path.join(out_dir, 'widget.png'), optimize=True)
        
        # 6. Supabase
        im_supa = process_supabase(lang)
        im_supa.convert('RGB').save(os.path.join(out_dir, 'supabase.png'), optimize=True)
        
        mode = "CLEAN (no overlays)" if lang == 'tr' else "ANNOTATED"
        print(f"  ✓ [{lang}] Generated 6 screenshots in {out_dir}/ ({mode})")
        
    print("🎉 All 60 screenshots regenerated successfully!")

if __name__ == '__main__':
    main()
