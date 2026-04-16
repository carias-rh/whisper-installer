# 🎤 Instalador Ansible para whisper.cpp

Este instalador configura automáticamente **whisper.cpp** en cualquier sistema Linux. Incluye un script wrapper en español que simplifica enormemente el uso.

## 🖥️ NUEVO: Interfaz Gráfica

¿No te gusta la terminal? ¡Ahora puedes usar Whisper con una interfaz gráfica moderna y sencilla!

![Whisper GUI](gui/whisper-transcriptor.svg)

### Instalación Rápida de la GUI

```bash
./instalar-gui.sh
```

### Características de la GUI

- **Fácil de usar**: Solo selecciona tu archivo y haz clic en "Transcribir"
- **Conversión automática**: Acepta MP3, M4A, OGG, FLAC y más (se convierte a WAV automáticamente)
- **Español por defecto**: Configurado para transcribir en español
- **Múltiples idiomas**: Soporte para 25+ idiomas
- **Varios formatos de salida**: TXT, SRT (subtítulos), VTT

### Cómo abrir la GUI

1. **Desde el menú de aplicaciones**: Busca "Whisper Transcriptor"
2. **Desde la terminal**: `whisper-gui`

---

## 🔧 Instalación por Terminal (Modo Tradicional)

| Modo | Comando | Cuándo usar |
|------|---------|-------------|
| **GUI** | `./instalar-gui.sh` | Usuarios que prefieren interfaz gráfica |
| **Contenedor** | `./instalar.sh` | CPUs modernos con AVX (la mayoría) |
| **Compilación** | `./build-install.sh` | CPUs sin AVX (Celeron, Atom antiguos) |

### ¿Cuál elegir?

```bash
# Verificar si tu CPU soporta AVX
grep -o 'avx[^ ]*' /proc/cpuinfo | head -1
```

- Si devuelve algo como `avx` o `avx2` → usa `./instalar.sh` (contenedor)
- Si no devuelve nada → usa `./build-install.sh` (compilación)

## 📋 Requisitos Previos

- Sistema Linux (Fedora, Ubuntu, Debian, Arch, openSUSE)
- Ansible instalado en tu máquina local
- Conexión a internet (para descargar el contenedor/código y modelos)
- Acceso SSH al servidor destino (o instalación local)

### Instalar Ansible

```bash
# Fedora / RHEL
sudo dnf install ansible

# Ubuntu / Debian
sudo apt install ansible

# Arch Linux
sudo pacman -S ansible

# Con pip (cualquier sistema)
pip install ansible
```

## 🚀 Instalación Rápida

### 1. Instalación Local (en tu propia máquina)

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml --ask-become-pass
```

### 2. Instalación con Compilación (CPUs sin AVX)

Para CPUs antiguos como Celeron N4500, Atom, etc:

```bash
cd ansible
./build-install.sh
```

Esto:
- Detecta automáticamente si tu CPU necesita compilación sin AVX
- Instala dependencias de compilación (gcc, cmake, git)
- Clona y compila whisper.cpp con las opciones correctas
- Instala el wrapper `whisper`

### 3. Instalación en Servidor Remoto

Primero, edita el archivo `inventory.ini`:

```ini
[whisper_servers]
mi_servidor ansible_host=192.168.1.100 ansible_user=mi_usuario
```

Luego ejecuta:

```bash
ansible-playbook -i inventory.ini site.yml --ask-become-pass
```

## 📖 Uso del Wrapper

Una vez instalado, tendrás disponible el comando `whisper` con una interfaz amigable en español.

### Ver Ayuda

```bash
whisper ayuda
```

### Transcribir Audio

```bash
# Transcripción básica
whisper transcribir mi_audio.wav

# Especificar idioma español
whisper transcribir entrevista.mp3 --idioma es

# Usar modelo más preciso
whisper transcribir podcast.wav --modelo medium

# Generar subtítulos SRT
whisper transcribir video_audio.wav --formato srt --idioma es

# Traducir al inglés
whisper transcribir audio_español.wav --traducir
```

### Gestionar Modelos

```bash
# Ver modelos disponibles e instalados
whisper modelos listar

# Descargar un modelo específico
whisper modelos descargar medium

# Eliminar un modelo
whisper modelos eliminar tiny
```

### Verificar Estado

```bash
whisper estado
```

## 📁 Estructura de Directorios

Después de la instalación, se crean los siguientes directorios en tu home:

```
~/whisper/
├── modelos/           # Modelos de IA descargados
├── audio/             # Puedes colocar aquí tus archivos de audio
└── transcripciones/   # Archivos de texto generados
```

El wrapper copia automáticamente el archivo de entrada a `~/whisper/audio` antes de transcribir, para evitar problemas de permisos/SELinux.

## 🎯 Modelos Disponibles

| Modelo | Tamaño | Velocidad | Precisión | Uso Recomendado |
|--------|--------|-----------|-----------|-----------------|
| `tiny` | ~75MB | Muy rápido | Baja | Pruebas rápidas |
| `base` | ~142MB | Rápido | Media | **Uso general** |
| `small` | ~466MB | Medio | Buena | Transcripciones importantes |
| `medium` | ~1.5GB | Lento | Alta | Audio difícil |
| `large` | ~3GB | Muy lento | Máxima | Máxima calidad |

Los modelos con sufijo `.en` (ej: `base.en`) están optimizados solo para inglés.

## 🌍 Idiomas Soportados

El wrapper soporta todos los idiomas de Whisper. Algunos ejemplos:

- `es` - Español
- `en` - Inglés  
- `ca` - Catalán
- `gl` - Gallego
- `eu` - Euskera
- `pt` - Portugués
- `fr` - Francés
- `de` - Alemán

Ver lista completa: `whisper idiomas`

## ⚙️ Configuración Avanzada

### Variables del Playbook

Puedes personalizar la instalación editando `site.yml`:

```yaml
vars:
  # Directorio base (usa /home/usuario)
  whisper_base_dir: "{{ whisper_user_home }}/whisper"
  
  # Modelo a descargar por defecto
  whisper_default_model: "base"
  
  # Imagen de contenedor (cambiar a main-cuda para GPU NVIDIA)
  whisper_container_image: "ghcr.io/ggml-org/whisper.cpp:main"
```

### Usar GPU NVIDIA (CUDA)

Para usar aceleración GPU, cambia la imagen en `site.yml`:

```yaml
whisper_container_image: "ghcr.io/ggml-org/whisper.cpp:main-cuda"
```

Y ejecuta con `--runtime=nvidia` en el contenedor (requiere nvidia-container-toolkit).

### SELinux

Si SELinux está activo, el playbook aplica automáticamente el contexto
`container_file_t` a los directorios `~/whisper/*` para que Podman pueda
montarlos sin errores de permisos.

## 🔧 Solución de Problemas

### El comando `whisper` no se encuentra

Reinicia tu terminal o ejecuta:

```bash
source ~/.bashrc
```

### Error de permisos con Podman

Asegúrate de que tu usuario puede ejecutar Podman sin sudo:

```bash
podman info
```

### El modelo no se descarga

Verifica tu conexión a internet y espacio en disco:

```bash
df -h ~/whisper/modelos
```

### Audio no reconocido

Whisper funciona mejor con archivos WAV. Convierte tu audio:

```bash
ffmpeg -i mi_audio.mp3 -ar 16000 -ac 1 mi_audio.wav
```

## 📝 Formatos de Salida

| Formato | Extensión | Descripción |
|---------|-----------|-------------|
| `txt` | .txt | Texto plano |
| `srt` | .srt | Subtítulos (compatible con la mayoría de reproductores) |
| `vtt` | .vtt | WebVTT (para web) |
| `json` | .json | Datos estructurados |
| `lrc` | .lrc | Letras sincronizadas |

## 🖥️ Uso de la Interfaz Gráfica

### Pasos para transcribir con la GUI

1. **Abre la aplicación** desde el menú o con `whisper-gui`
2. **Selecciona tu archivo de audio** (cualquier formato: MP3, WAV, M4A, etc.)
3. **Elige el idioma** del audio (español por defecto)
4. **Selecciona el modelo** (base es suficiente para la mayoría de casos)
5. **Haz clic en "Iniciar Transcripción"**
6. **¡Listo!** El texto aparecerá y se guardará en `~/whisper/transcripciones/`

### Solución de Problemas de la GUI

#### La aplicación no aparece en el menú
Cierra sesión y vuelve a entrar, o ejecuta:
```bash
update-desktop-database ~/.local/share/applications
```

#### Error "whisper: command not found"
Asegúrate de que instalaste también whisper.cpp:
```bash
./instalar-gui.sh  # Instala todo junto
```

#### Error al convertir audio
Verifica que ffmpeg esté instalado:
```bash
ffmpeg -version
```

## 🤝 Contribuir

Si encuentras algún problema o tienes sugerencias, no dudes en abrir un issue en el repositorio.

## 📜 Licencia

Este instalador sigue la misma licencia que whisper.cpp (MIT).

---

**¡Disfruta transcribiendo audio con whisper.cpp! 🎉**
