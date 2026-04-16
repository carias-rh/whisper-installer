#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Whisper GUI - Interfaz gráfica para transcripción de audio
Una aplicación sencilla y amigable para usuarios no técnicos
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Gio, Pango
import subprocess
import threading
import os
import shutil
from pathlib import Path

# Configuración por defecto
DEFAULT_LANGUAGE = "es"
WHISPER_BASE = Path.home() / "whisper"
WHISPER_AUDIO = WHISPER_BASE / "audio"
WHISPER_OUTPUT = WHISPER_BASE / "transcripciones"
WHISPER_MODELS = WHISPER_BASE / "modelos"
WHISPER_BIN = Path.home() / ".local" / "bin" / "whisper"

# Idiomas disponibles
LANGUAGES = {
    "es": "Español",
    "en": "Inglés",
    "pt": "Portugués",
    "fr": "Francés",
    "de": "Alemán",
    "it": "Italiano",
    "ca": "Catalán",
    "gl": "Gallego",
    "eu": "Euskera",
    "nl": "Neerlandés",
    "pl": "Polaco",
    "ru": "Ruso",
    "zh": "Chino",
    "ja": "Japonés",
    "ko": "Coreano",
    "ar": "Árabe",
}

# Modelos disponibles
MODELS = {
    "tiny": "Tiny - Muy rápido (~75MB)",
    "base": "Base - Equilibrado (~142MB)",
    "small": "Small - Buena precisión (~466MB)",
    "medium": "Medium - Alta precisión (~1.5GB)",
    "large-v3": "Large - Máxima precisión (~3GB)",
}

# Formatos de salida
OUTPUT_FORMATS = {
    "txt": "Texto plano (.txt)",
    "srt": "Subtítulos SRT (.srt)",
    "vtt": "WebVTT (.vtt)",
}


class WhisperGUI(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id="org.whisper.transcriptor",
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        self.window = None
        self.selected_file = None
        self.is_processing = False

    def do_activate(self):
        if not self.window:
            self.window = WhisperWindow(application=self)
        self.window.present()


class WhisperWindow(Gtk.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        self.selected_file = None
        self.is_processing = False
        self.process = None
        
        self.setup_window()
        self.setup_css()
        self.setup_ui()
        
    def setup_window(self):
        self.set_title("Whisper - Transcriptor de Audio")
        self.set_default_size(750, 850)
        self.set_size_request(650, 700)  # Tamaño mínimo
        self.set_position(Gtk.WindowPosition.CENTER)

        # Icono de la ventana
        try:
            self.set_icon_name("audio-x-generic")
        except:
            pass

    def setup_css(self):
        css_provider = Gtk.CssProvider()
        css = b"""
        .main-container {
            background: linear-gradient(180deg, #f5f5f5 0%, #e8e8e8 100%);
        }
        
        .header-box {
            background: linear-gradient(180deg, #3584e4 0%, #1c71d8 100%);
            padding: 20px;
            border-radius: 0 0 12px 12px;
        }
        
        .header-title {
            color: white;
            font-size: 24px;
            font-weight: bold;
        }
        
        .header-subtitle {
            color: rgba(255, 255, 255, 0.9);
            font-size: 14px;
        }
        
        .card {
            background: white;
            border-radius: 12px;
            padding: 20px;
            margin: 10px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }
        
        .card-title {
            font-size: 16px;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        
        .file-button {
            padding: 30px 20px;
            border-radius: 12px;
            border: 2px dashed #3584e4;
            background: #f0f6ff;
            font-size: 14px;
        }
        
        .file-button:hover {
            background: #e0edff;
            border-color: #1c71d8;
        }
        
        .file-selected {
            border: 2px solid #2ec27e;
            background: #f0fff4;
        }
        
        .transcribe-button {
            padding: 15px 40px;
            border-radius: 8px;
            background: linear-gradient(180deg, #2ec27e 0%, #26a269 100%);
            color: white;
            font-size: 16px;
            font-weight: bold;
            border: none;
        }
        
        .transcribe-button:hover {
            background: linear-gradient(180deg, #26a269 0%, #1e8c5a 100%);
        }
        
        .transcribe-button:disabled {
            background: #ccc;
            color: #888;
        }
        
        .output-view {
            font-family: monospace;
            font-size: 12px;
            padding: 10px;
            background: #2d2d2d;
            color: #f0f0f0;
            border-radius: 8px;
        }
        
        .status-bar {
            background: #333;
            color: white;
            padding: 8px 15px;
            font-size: 12px;
        }
        
        .spinner {
            color: #3584e4;
        }
        
        .success-label {
            color: #2ec27e;
            font-weight: bold;
        }
        
        .error-label {
            color: #e01b24;
            font-weight: bold;
        }
        """
        css_provider.load_from_data(css)
        
        screen = Gdk.Screen.get_default()
        Gtk.StyleContext.add_provider_for_screen(
            screen,
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def setup_ui(self):
        # Contenedor principal
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.get_style_context().add_class("main-container")
        self.add(main_box)
        
        # Header
        header = self.create_header()
        main_box.pack_start(header, False, False, 0)
        
        # Contenido scrollable
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        main_box.pack_start(scrolled, True, True, 0)
        
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        content_box.set_margin_start(20)
        content_box.set_margin_end(20)
        content_box.set_margin_top(10)
        content_box.set_margin_bottom(20)
        scrolled.add(content_box)
        
        # Tarjeta de selección de archivo
        file_card = self.create_file_card()
        content_box.pack_start(file_card, False, False, 0)
        
        # Tarjeta de opciones
        options_card = self.create_options_card()
        content_box.pack_start(options_card, False, False, 0)
        
        # Botón de transcribir
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        button_box.set_halign(Gtk.Align.CENTER)
        button_box.set_margin_top(10)
        button_box.set_margin_bottom(10)
        
        self.transcribe_button = Gtk.Button(label="🎤  Iniciar Transcripción")
        self.transcribe_button.get_style_context().add_class("transcribe-button")
        self.transcribe_button.connect("clicked", self.on_transcribe_clicked)
        self.transcribe_button.set_sensitive(False)
        button_box.pack_start(self.transcribe_button, False, False, 0)
        
        content_box.pack_start(button_box, False, False, 0)
        
        # Tarjeta de salida/progreso
        output_card = self.create_output_card()
        content_box.pack_start(output_card, True, True, 0)
        
        # Barra de estado
        self.status_bar = Gtk.Label(label="Listo para transcribir")
        self.status_bar.get_style_context().add_class("status-bar")
        self.status_bar.set_xalign(0)
        main_box.pack_end(self.status_bar, False, False, 0)
        
        self.show_all()
        self.progress_box.hide()

    def create_header(self):
        header_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        header_box.get_style_context().add_class("header-box")
        
        title = Gtk.Label(label="Whisper Transcriptor")
        title.get_style_context().add_class("header-title")
        title.set_xalign(0)
        header_box.pack_start(title, False, False, 0)
        
        subtitle = Gtk.Label(label="Convierte audio a texto con inteligencia artificial")
        subtitle.get_style_context().add_class("header-subtitle")
        subtitle.set_xalign(0)
        header_box.pack_start(subtitle, False, False, 0)
        
        return header_box

    def create_file_card(self):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        card.get_style_context().add_class("card")
        
        title = Gtk.Label(label="1. Selecciona tu archivo de audio")
        title.get_style_context().add_class("card-title")
        title.set_xalign(0)
        card.pack_start(title, False, False, 0)
        
        # Botón de selección de archivo
        self.file_button = Gtk.Button()
        self.file_button.get_style_context().add_class("file-button")
        self.file_button.connect("clicked", self.on_file_button_clicked)
        
        file_button_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        file_button_box.set_halign(Gtk.Align.CENTER)
        
        icon = Gtk.Image.new_from_icon_name("document-open", Gtk.IconSize.DIALOG)
        file_button_box.pack_start(icon, False, False, 0)
        
        self.file_label = Gtk.Label(label="Haz clic para seleccionar un archivo\n(MP3, WAV, M4A, OGG, FLAC, etc.)")
        self.file_label.set_justify(Gtk.Justification.CENTER)
        file_button_box.pack_start(self.file_label, False, False, 0)
        
        self.file_button.add(file_button_box)
        card.pack_start(self.file_button, False, False, 0)
        
        # Info del archivo seleccionado
        self.file_info = Gtk.Label()
        self.file_info.set_line_wrap(True)
        self.file_info.set_xalign(0)
        card.pack_start(self.file_info, False, False, 0)
        
        return card

    def create_options_card(self):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        card.get_style_context().add_class("card")
        
        title = Gtk.Label(label="2. Configura las opciones")
        title.get_style_context().add_class("card-title")
        title.set_xalign(0)
        card.pack_start(title, False, False, 0)
        
        # Grid para opciones
        grid = Gtk.Grid()
        grid.set_column_spacing(20)
        grid.set_row_spacing(15)
        card.pack_start(grid, False, False, 0)
        
        # Idioma
        lang_label = Gtk.Label(label="Idioma del audio:")
        lang_label.set_xalign(1)
        grid.attach(lang_label, 0, 0, 1, 1)
        
        self.lang_combo = Gtk.ComboBoxText()
        for code, name in LANGUAGES.items():
            self.lang_combo.append(code, name)
        self.lang_combo.set_active_id(DEFAULT_LANGUAGE)
        self.lang_combo.set_hexpand(True)
        grid.attach(self.lang_combo, 1, 0, 1, 1)
        
        # Modelo
        model_label = Gtk.Label(label="Modelo de IA:")
        model_label.set_xalign(1)
        grid.attach(model_label, 0, 1, 1, 1)
        
        self.model_combo = Gtk.ComboBoxText()
        for code, name in MODELS.items():
            self.model_combo.append(code, name)
        self.model_combo.set_active_id("base")
        self.model_combo.set_hexpand(True)
        grid.attach(self.model_combo, 1, 1, 1, 1)
        
        # Formato de salida
        format_label = Gtk.Label(label="Formato de salida:")
        format_label.set_xalign(1)
        grid.attach(format_label, 0, 2, 1, 1)
        
        self.format_combo = Gtk.ComboBoxText()
        for code, name in OUTPUT_FORMATS.items():
            self.format_combo.append(code, name)
        self.format_combo.set_active_id("txt")
        self.format_combo.set_hexpand(True)
        grid.attach(self.format_combo, 1, 2, 1, 1)
        
        # Nota informativa
        info_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        info_box.set_margin_top(10)
        
        info_icon = Gtk.Image.new_from_icon_name("dialog-information", Gtk.IconSize.SMALL_TOOLBAR)
        info_box.pack_start(info_icon, False, False, 0)
        
        info_text = Gtk.Label(label="El audio se convertirá automáticamente al formato correcto si es necesario.")
        info_text.set_line_wrap(True)
        info_text.set_xalign(0)
        info_text.get_style_context().add_class("dim-label")
        info_box.pack_start(info_text, True, True, 0)
        
        card.pack_start(info_box, False, False, 0)
        
        return card

    def create_output_card(self):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        card.get_style_context().add_class("card")
        
        title = Gtk.Label(label="3. Resultado")
        title.get_style_context().add_class("card-title")
        title.set_xalign(0)
        card.pack_start(title, False, False, 0)
        
        # Caja de progreso
        self.progress_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        
        progress_header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.spinner = Gtk.Spinner()
        self.spinner.get_style_context().add_class("spinner")
        progress_header.pack_start(self.spinner, False, False, 0)
        
        self.progress_label = Gtk.Label(label="Procesando...")
        progress_header.pack_start(self.progress_label, False, False, 0)
        
        self.progress_box.pack_start(progress_header, False, False, 0)
        
        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_pulse_step(0.1)
        self.progress_box.pack_start(self.progress_bar, False, False, 0)
        
        card.pack_start(self.progress_box, False, False, 0)
        
        # Vista de texto para la salida
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_min_content_height(200)
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        
        self.output_view = Gtk.TextView()
        self.output_view.set_editable(False)
        self.output_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.output_view.get_style_context().add_class("output-view")
        self.output_buffer = self.output_view.get_buffer()
        scrolled.add(self.output_view)
        
        card.pack_start(scrolled, True, True, 0)
        
        # Botones de resultado
        self.result_buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.result_buttons.set_margin_top(10)
        
        self.open_file_button = Gtk.Button(label="📄 Abrir archivo")
        self.open_file_button.connect("clicked", self.on_open_file_clicked)
        self.result_buttons.pack_start(self.open_file_button, False, False, 0)
        
        self.open_folder_button = Gtk.Button(label="📁 Abrir carpeta")
        self.open_folder_button.connect("clicked", self.on_open_folder_clicked)
        self.result_buttons.pack_start(self.open_folder_button, False, False, 0)
        
        self.copy_button = Gtk.Button(label="📋 Copiar texto")
        self.copy_button.connect("clicked", self.on_copy_clicked)
        self.result_buttons.pack_start(self.copy_button, False, False, 0)
        
        card.pack_start(self.result_buttons, False, False, 0)
        self.result_buttons.hide()
        
        return card

    def on_file_button_clicked(self, button):
        dialog = Gtk.FileChooserDialog(
            title="Seleccionar archivo de audio",
            parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        
        # Filtro para archivos de audio
        filter_audio = Gtk.FileFilter()
        filter_audio.set_name("Archivos de audio")
        filter_audio.add_mime_type("audio/*")
        filter_audio.add_pattern("*.mp3")
        filter_audio.add_pattern("*.wav")
        filter_audio.add_pattern("*.m4a")
        filter_audio.add_pattern("*.ogg")
        filter_audio.add_pattern("*.flac")
        filter_audio.add_pattern("*.aac")
        filter_audio.add_pattern("*.wma")
        filter_audio.add_pattern("*.opus")
        dialog.add_filter(filter_audio)
        
        # Filtro para todos los archivos
        filter_all = Gtk.FileFilter()
        filter_all.set_name("Todos los archivos")
        filter_all.add_pattern("*")
        dialog.add_filter(filter_all)
        
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            self.selected_file = dialog.get_filename()
            self.update_file_selection()
        
        dialog.destroy()

    def update_file_selection(self):
        if self.selected_file:
            filename = os.path.basename(self.selected_file)
            filesize = os.path.getsize(self.selected_file)
            size_str = self.format_size(filesize)
            
            self.file_label.set_text(f"✅ {filename}")
            self.file_info.set_markup(f"<small>Tamaño: {size_str} | Ubicación: {os.path.dirname(self.selected_file)}</small>")
            self.file_button.get_style_context().add_class("file-selected")
            self.transcribe_button.set_sensitive(True)
            self.status_bar.set_text(f"Archivo seleccionado: {filename}")

    def format_size(self, size):
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"

    def on_transcribe_clicked(self, button):
        if self.is_processing:
            self.cancel_transcription()
            return
            
        if not self.selected_file:
            return
        
        self.start_transcription()

    def start_transcription(self):
        self.is_processing = True
        self.transcribe_button.set_label("⏹ Cancelar")
        self.transcribe_button.get_style_context().remove_class("transcribe-button")
        
        self.progress_box.show()
        self.result_buttons.hide()
        self.spinner.start()
        self.output_buffer.set_text("")
        
        # Obtener opciones
        language = self.lang_combo.get_active_id()
        model = self.model_combo.get_active_id()
        output_format = self.format_combo.get_active_id()
        
        # Iniciar proceso en un thread separado
        thread = threading.Thread(
            target=self.run_transcription,
            args=(self.selected_file, language, model, output_format)
        )
        thread.daemon = True
        thread.start()
        
        # Iniciar pulso de la barra de progreso
        GLib.timeout_add(100, self.pulse_progress)

    def pulse_progress(self):
        if self.is_processing:
            self.progress_bar.pulse()
            return True
        return False

    def run_transcription(self, input_file, language, model, output_format):
        try:
            # Actualizar UI
            GLib.idle_add(self.update_progress, "Preparando archivo de audio...")
            GLib.idle_add(self.append_output, f"📁 Archivo: {input_file}\n")
            GLib.idle_add(self.append_output, f"🌍 Idioma: {LANGUAGES.get(language, language)}\n")
            GLib.idle_add(self.append_output, f"🤖 Modelo: {model}\n")
            GLib.idle_add(self.append_output, f"📄 Formato: {output_format}\n\n")
            
            # Asegurar directorios
            WHISPER_AUDIO.mkdir(parents=True, exist_ok=True)
            WHISPER_OUTPUT.mkdir(parents=True, exist_ok=True)
            
            # Convertir a WAV si es necesario
            input_path = Path(input_file)
            wav_file = WHISPER_AUDIO / f"{input_path.stem}.wav"
            
            if input_path.suffix.lower() != '.wav':
                GLib.idle_add(self.update_progress, "Convirtiendo audio a formato WAV...")
                GLib.idle_add(self.append_output, "🔄 Convirtiendo audio a WAV...\n")
                
                # Usar ffmpeg para convertir
                convert_cmd = [
                    "ffmpeg", "-y", "-i", str(input_file),
                    "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le",
                    str(wav_file)
                ]
                
                result = subprocess.run(
                    convert_cmd,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    raise Exception(f"Error al convertir audio: {result.stderr}")
                
                GLib.idle_add(self.append_output, "✅ Audio convertido correctamente\n\n")
            else:
                # Copiar archivo WAV al directorio de trabajo (si no es el mismo archivo)
                input_resolved = Path(input_file).resolve()
                wav_resolved = wav_file.resolve()
                if input_resolved != wav_resolved:
                    shutil.copy2(input_file, wav_file)
                    GLib.idle_add(self.append_output, "✅ Archivo WAV copiado\n\n")
                else:
                    GLib.idle_add(self.append_output, "✅ Archivo WAV listo\n\n")
            
            # Buscar el comando whisper en varias ubicaciones
            whisper_bin = None
            for path in [WHISPER_BIN, Path("/usr/local/bin/whisper"), Path("/usr/bin/whisper")]:
                if path.exists():
                    whisper_bin = str(path)
                    break
            
            if not whisper_bin:
                whisper_bin = shutil.which("whisper")
            
            if not whisper_bin:
                raise Exception("No se encontró el comando 'whisper'. ¿Está instalado?\n"
                              f"Esperado en: {WHISPER_BIN}")
            
            # Verificar si el modelo existe, si no, descargarlo primero
            model_file = WHISPER_MODELS / f"ggml-{model}.bin"
            if not model_file.exists():
                GLib.idle_add(self.update_progress, f"Descargando modelo {model}...")
                GLib.idle_add(self.append_output, f"📥 El modelo '{model}' no está instalado.\n")
                GLib.idle_add(self.append_output, f"📥 Descargando... (esto puede tardar varios minutos)\n\n")
                
                download_cmd = [whisper_bin, "modelos", "descargar", model]
                download_process = subprocess.Popen(
                    download_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    stdin=subprocess.DEVNULL,
                    text=True,
                    bufsize=1
                )
                
                for line in iter(download_process.stdout.readline, ''):
                    if not self.is_processing:
                        download_process.terminate()
                        break
                    clean_line = self.strip_ansi(line)
                    if clean_line.strip():
                        GLib.idle_add(self.append_output, clean_line)
                
                download_process.wait()
                
                if download_process.returncode != 0:
                    raise Exception(f"Error al descargar el modelo '{model}'")
                
                GLib.idle_add(self.append_output, "\n✅ Modelo descargado correctamente\n\n")
            
            # Ejecutar whisper
            GLib.idle_add(self.update_progress, "Transcribiendo audio con Whisper...")
            GLib.idle_add(self.append_output, "🎤 Iniciando transcripción...\n")
            GLib.idle_add(self.append_output, "(Esto puede tomar varios minutos)\n\n")
            
            whisper_cmd = [
                whisper_bin, "transcribir", str(wav_file),
                "--idioma", language,
                "--modelo", model,
                "--formato", output_format
            ]
            
            self.process = subprocess.Popen(
                whisper_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                text=True,
                bufsize=1
            )
            
            # Leer salida línea por línea (filtrando códigos ANSI)
            for line in iter(self.process.stdout.readline, ''):
                if not self.is_processing:
                    break
                clean_line = self.strip_ansi(line)
                if clean_line.strip():
                    GLib.idle_add(self.append_output, clean_line)
            
            self.process.wait()
            
            if not self.is_processing:
                GLib.idle_add(self.append_output, "\n⚠️ Transcripción cancelada\n")
                GLib.idle_add(self.finish_transcription, False)
                return
            
            if self.process.returncode == 0:
                # Buscar archivo de salida
                output_file = WHISPER_OUTPUT / f"{input_path.stem}.{output_format}"
                self.output_file = output_file
                
                GLib.idle_add(self.append_output, f"\n✅ ¡Transcripción completada!\n")
                GLib.idle_add(self.append_output, f"📄 Archivo guardado en: {output_file}\n")
                
                # Leer y mostrar contenido
                if output_file.exists():
                    with open(output_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    GLib.idle_add(self.append_output, f"\n{'─' * 50}\n")
                    GLib.idle_add(self.append_output, f"TRANSCRIPCIÓN:\n{'─' * 50}\n")
                    GLib.idle_add(self.append_output, content)
                
                GLib.idle_add(self.finish_transcription, True)
            else:
                GLib.idle_add(self.append_output, "\n❌ Error en la transcripción\n")
                GLib.idle_add(self.finish_transcription, False)
                
        except Exception as e:
            GLib.idle_add(self.append_output, f"\n❌ Error: {str(e)}\n")
            GLib.idle_add(self.finish_transcription, False)

    def update_progress(self, text):
        self.progress_label.set_text(text)
        self.status_bar.set_text(text)

    def append_output(self, text):
        end_iter = self.output_buffer.get_end_iter()
        self.output_buffer.insert(end_iter, text)
        # Auto-scroll
        mark = self.output_buffer.create_mark(None, self.output_buffer.get_end_iter(), False)
        self.output_view.scroll_to_mark(mark, 0, False, 0, 0)

    def strip_ansi(self, text):
        """Elimina códigos de escape ANSI del texto"""
        import re
        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        return ansi_escape.sub('', text)

    def finish_transcription(self, success):
        self.is_processing = False
        self.spinner.stop()
        self.progress_box.hide()
        
        self.transcribe_button.set_label("🎤  Iniciar Transcripción")
        self.transcribe_button.get_style_context().add_class("transcribe-button")
        
        if success:
            self.result_buttons.show()
            self.status_bar.set_text("✅ Transcripción completada con éxito")
        else:
            self.status_bar.set_text("❌ Error en la transcripción")

    def cancel_transcription(self):
        self.is_processing = False
        if self.process:
            self.process.terminate()
        self.status_bar.set_text("⚠️ Transcripción cancelada")

    def on_open_file_clicked(self, button):
        if hasattr(self, 'output_file') and self.output_file.exists():
            subprocess.run(["xdg-open", str(self.output_file)])

    def on_open_folder_clicked(self, button):
        subprocess.run(["xdg-open", str(WHISPER_OUTPUT)])

    def on_copy_clicked(self, button):
        start, end = self.output_buffer.get_bounds()
        text = self.output_buffer.get_text(start, end, True)
        
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text(text, -1)
        clipboard.store()
        
        self.status_bar.set_text("📋 Texto copiado al portapapeles")


def main():
    app = WhisperGUI()
    app.run(None)


if __name__ == "__main__":
    main()
