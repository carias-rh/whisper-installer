#!/bin/bash
# ============================================================================
# Exportar imagen de whisper.cpp para instalación offline
# Ejecutar con: ./exportar-imagen.sh [directorio_destino]
# ============================================================================

set -e

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

IMAGEN="ghcr.io/ggml-org/whisper.cpp:main"
DESTINO="${1:-.}"
ARCHIVO_IMAGEN="whisper-cpp-image.tar"
ARCHIVO_MODELO="ggml-base.bin"

echo -e "${AZUL}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Exportar whisper.cpp para instalación offline 📦        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar podman
if ! command -v podman &> /dev/null; then
    echo -e "${ROJO}❌ Podman no está instalado${NC}"
    exit 1
fi

# Verificar que la imagen existe
if ! podman image exists "$IMAGEN" 2>/dev/null; then
    echo -e "${AMARILLO}⚠️  La imagen no existe localmente. Descargando...${NC}"
    podman pull "$IMAGEN"
fi

# Crear directorio destino si no existe
mkdir -p "$DESTINO"

echo ""
echo -e "${AZUL}ℹ️  Exportando imagen de contenedor...${NC}"
echo "   Esto puede tardar unos minutos (~1.1GB)"
echo ""

podman save -o "$DESTINO/$ARCHIVO_IMAGEN" "$IMAGEN"

echo -e "${VERDE}✅ Imagen exportada: $DESTINO/$ARCHIVO_IMAGEN${NC}"

# Obtener tamaño
TAMANO=$(du -h "$DESTINO/$ARCHIVO_IMAGEN" | cut -f1)
echo "   Tamaño: $TAMANO"

# Preguntar si descargar modelo base
echo ""
echo -e "${AMARILLO}¿Deseas incluir también el modelo base (~142MB)? [S/n]${NC}"
read -r respuesta

if [[ ! "$respuesta" =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${AZUL}ℹ️  Descargando modelo base...${NC}"
    
    # Descargar modelo usando el contenedor
    TEMP_DIR=$(mktemp -d)
    podman run --rm \
        -v "$TEMP_DIR:/models:z" \
        "$IMAGEN" \
        "./models/download-ggml-model.sh base /models"
    
    if [ -f "$TEMP_DIR/ggml-base.bin" ]; then
        mv "$TEMP_DIR/ggml-base.bin" "$DESTINO/$ARCHIVO_MODELO"
        echo -e "${VERDE}✅ Modelo exportado: $DESTINO/$ARCHIVO_MODELO${NC}"
        TAMANO_MODELO=$(du -h "$DESTINO/$ARCHIVO_MODELO" | cut -f1)
        echo "   Tamaño: $TAMANO_MODELO"
    fi
    rm -rf "$TEMP_DIR"
fi

# Copiar archivos de ansible (solo si destino es diferente)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESTINO_ABS="$(cd "$DESTINO" && pwd)"

if [ "$SCRIPT_DIR" != "$DESTINO_ABS" ]; then
    echo ""
    echo -e "${AZUL}ℹ️  Copiando archivos de instalación...${NC}"
    cp -r "$SCRIPT_DIR" "$DESTINO_ABS/ansible"
else
    echo ""
    echo -e "${AZUL}ℹ️  Archivos de Ansible ya están en el directorio destino${NC}"
fi

# Crear script de instalación offline
cat > "$DESTINO/instalar-offline.sh" << 'EOFINSTALL'
#!/bin/bash
# ============================================================================
# Instalación offline de whisper.cpp desde USB
# ============================================================================

set -e

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${AZUL}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Instalación offline de whisper.cpp 📦➜💻                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar archivos necesarios
if [ ! -f "$SCRIPT_DIR/whisper-cpp-image.tar" ]; then
    echo -e "${ROJO}❌ No se encontró whisper-cpp-image.tar${NC}"
    exit 1
fi

# Verificar/instalar podman
if ! command -v podman &> /dev/null; then
    echo -e "${AMARILLO}⚠️  Podman no está instalado.${NC}"
    echo "Instalando Podman..."
    
    if [ -f /etc/fedora-release ]; then
        sudo dnf install -y podman
    elif [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y podman
    elif [ -f /etc/arch-release ]; then
        sudo pacman -S --noconfirm podman
    else
        echo -e "${ROJO}❌ No se pudo detectar la distribución. Instala Podman manualmente.${NC}"
        exit 1
    fi
fi

echo -e "${VERDE}✓ Podman disponible${NC}"

# Cargar imagen
echo ""
echo -e "${AZUL}ℹ️  Cargando imagen de contenedor...${NC}"
echo "   Esto puede tardar unos minutos..."

podman load -i "$SCRIPT_DIR/whisper-cpp-image.tar"

echo -e "${VERDE}✅ Imagen cargada correctamente${NC}"

# Crear directorios
WHISPER_DIR="$HOME/whisper"
mkdir -p "$WHISPER_DIR/modelos" "$WHISPER_DIR/audio" "$WHISPER_DIR/transcripciones"
mkdir -p "$HOME/.local/bin"

# Copiar modelo si existe
if [ -f "$SCRIPT_DIR/ggml-base.bin" ]; then
    echo ""
    echo -e "${AZUL}ℹ️  Copiando modelo base...${NC}"
    cp "$SCRIPT_DIR/ggml-base.bin" "$WHISPER_DIR/modelos/"
    echo -e "${VERDE}✅ Modelo copiado${NC}"
fi

# Ejecutar playbook de ansible si está disponible
if [ -d "$SCRIPT_DIR/ansible" ] && command -v ansible-playbook &> /dev/null; then
    echo ""
    echo -e "${AZUL}ℹ️  Ejecutando configuración con Ansible...${NC}"
    cd "$SCRIPT_DIR/ansible"
    
    # Instalar colecciones de ansible si hay conexión o están cacheadas
    ansible-galaxy collection install -r requirements.yml 2>/dev/null || true
    
    # Ejecutar playbook con la imagen ya cargada
    ansible-playbook -i inventory.ini site.yml --connection=local --ask-become-pass \
        -e "whisper_skip_image_pull=true"
else
    # Instalación manual mínima sin ansible
    echo ""
    echo -e "${AZUL}ℹ️  Creando script wrapper...${NC}"
    
    cat > "$HOME/.local/bin/whisper" << 'EOFWRAPPER'
#!/bin/bash
# Wrapper mínimo para whisper.cpp (instalación offline)

WHISPER_MODELOS="$HOME/whisper/modelos"
WHISPER_AUDIO="$HOME/whisper/audio"
WHISPER_OUTPUT="$HOME/whisper/transcripciones"
WHISPER_IMAGEN="ghcr.io/ggml-org/whisper.cpp:main"

case "${1:-ayuda}" in
    transcribir|t)
        shift
        archivo="$1"
        shift
        
        if [ -z "$archivo" ]; then
            echo "Uso: whisper transcribir <archivo.wav>"
            exit 1
        fi
        
        # Copiar archivo a directorio de audio
        cp "$archivo" "$WHISPER_AUDIO/"
        nombre=$(basename "$archivo")
        
        echo "Transcribiendo: $nombre"
        podman run --rm \
            -v "$WHISPER_MODELOS:/models:z" \
            -v "$WHISPER_AUDIO:/audio:z" \
            -v "$WHISPER_OUTPUT:/output:z" \
            "$WHISPER_IMAGEN" \
            "whisper-cli -m /models/ggml-base.bin -f /audio/$nombre -otxt -of /output/${nombre%.*} $*"
        
        echo "Transcripción guardada en: $WHISPER_OUTPUT/${nombre%.*}.txt"
        ;;
    modelos|m)
        echo "Modelos instalados:"
        ls -lh "$WHISPER_MODELOS"/*.bin 2>/dev/null || echo "No hay modelos"
        ;;
    ayuda|help|*)
        echo "Uso: whisper <comando>"
        echo ""
        echo "Comandos:"
        echo "  transcribir <archivo>  Transcribir audio"
        echo "  modelos                Listar modelos"
        echo "  ayuda                  Esta ayuda"
        ;;
esac
EOFWRAPPER
    chmod +x "$HOME/.local/bin/whisper"
    echo -e "${VERDE}✅ Wrapper instalado${NC}"
fi

# Configurar PATH
if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ] && ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo ""
echo -e "${VERDE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${VERDE}║          ¡Instalación completada! 🎉                         ║${NC}"
echo -e "${VERDE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Para empezar a usar whisper:"
echo ""
echo "  1. Reinicia tu terminal o ejecuta: source ~/.bashrc"
echo "  2. Prueba con: whisper ayuda"
echo "  3. Transcribe tu primer audio: whisper transcribir mi_audio.wav"
echo ""
EOFINSTALL

chmod +x "$DESTINO/instalar-offline.sh"

# Crear README
cat > "$DESTINO/LEEME.txt" << 'EOFREADME'
╔══════════════════════════════════════════════════════════════════╗
║           whisper.cpp - Instalación Offline 📦                   ║
╚══════════════════════════════════════════════════════════════════╝

CONTENIDO DEL USB:
  • whisper-cpp-image.tar  - Imagen del contenedor (~1.1GB)
  • ggml-base.bin          - Modelo de IA base (~142MB)
  • instalar-offline.sh    - Script de instalación
  • ansible/               - Archivos de configuración avanzada

INSTALACIÓN RÁPIDA:
  1. Conecta el USB al ordenador destino
  2. Abre una terminal en el directorio del USB
  3. Ejecuta: ./instalar-offline.sh
  4. Sigue las instrucciones en pantalla

REQUISITOS:
  • Sistema Linux (Fedora, Ubuntu, Debian, Arch)
  • Conexión a internet NO necesaria (instalación offline)
  • ~2GB de espacio libre en disco

USO DESPUÉS DE INSTALAR:
  whisper transcribir mi_audio.wav
  whisper ayuda

MODELOS ADICIONALES:
  Si necesitas más precisión, descarga modelos adicionales cuando
  tengas conexión a internet:
    whisper modelos descargar medium
    whisper modelos descargar large

SOPORTE:
  https://github.com/ggml-org/whisper.cpp

╚══════════════════════════════════════════════════════════════════╝
EOFREADME

echo ""
echo -e "${VERDE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${VERDE}║          ¡Exportación completada! 🎉                         ║${NC}"
echo -e "${VERDE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Archivos creados en: $DESTINO"
echo ""
ls -lh "$DESTINO"/*.tar "$DESTINO"/*.bin "$DESTINO"/*.sh "$DESTINO"/*.txt 2>/dev/null || true
echo ""
echo -e "${AMARILLO}Copia el contenido de '$DESTINO' a un USB para instalación offline.${NC}"
echo ""
