#!/bin/bash
# ============================================================================
# build-install.sh - Compilar e instalar whisper.cpp desde código fuente
# Para CPUs sin AVX (Celeron, Atom, etc.) o preferencia de instalación nativa
# ============================================================================
# Uso:
#   ./build-install.sh              # Instalación online (descarga todo)
#   ./build-install.sh --offline    # Instalación offline desde USB
# ============================================================================

set -e

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OFFLINE_MODE=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline|-o)
            OFFLINE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --offline, -o    Instalación offline desde USB"
            echo "  --help, -h       Mostrar esta ayuda"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║   Compilar e instalar whisper.cpp (versión nativa) 🔧       ║"
echo "║                                                              ║"
echo "║   Para CPUs sin AVX (Celeron, Atom, etc.)                   ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detectar soporte AVX
echo -e "${AZUL}ℹ️  Detectando características del CPU...${NC}"
AVX_SUPPORT=$(grep -o 'avx[^ ]*' /proc/cpuinfo 2>/dev/null | head -1 || echo "")

if [ -n "$AVX_SUPPORT" ]; then
    echo -e "${VERDE}✓ CPU con soporte AVX detectado ($AVX_SUPPORT)${NC}"
    echo ""
    echo -e "${AMARILLO}Tu CPU soporta AVX. Podrías usar la versión con contenedor que es más fácil.${NC}"
    echo -e "${AMARILLO}¿Continuar con la compilación nativa de todos modos? [s/N]${NC}"
    read -r respuesta
    if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
        echo ""
        echo "Para usar la versión con contenedor, ejecuta:"
        echo -e "  ${CYAN}./instalar.sh${NC}"
        exit 0
    fi
else
    echo -e "${AMARILLO}⚠ CPU sin soporte AVX detectado${NC}"
    echo -e "${VERDE}✓ Compilación nativa es la opción correcta para tu hardware${NC}"
fi
echo ""

# Verificar/instalar Ansible
if ! command -v ansible &> /dev/null; then
    echo -e "${AMARILLO}⚠️  Ansible no está instalado.${NC}"
    echo ""
    
    if [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
        echo "Detectado: Fedora/RHEL"
        echo -e "${AZUL}Instalando Ansible...${NC}"
        sudo dnf install -y ansible git
    elif [ -f /etc/debian_version ]; then
        echo "Detectado: Debian/Ubuntu"
        echo -e "${AZUL}Instalando Ansible...${NC}"
        sudo apt update && sudo apt install -y ansible git
    elif [ -f /etc/arch-release ]; then
        echo "Detectado: Arch Linux"
        echo -e "${AZUL}Instalando Ansible...${NC}"
        sudo pacman -S --noconfirm ansible git
    else
        echo -e "${ROJO}❌ No se pudo detectar la distribución.${NC}"
        echo "Por favor, instala Ansible y Git manualmente:"
        echo "  pip install ansible"
        exit 1
    fi
fi

echo -e "${VERDE}✓ Ansible disponible${NC}"

# Instalar colecciones de Ansible (solo si hay conexión)
if [ "$OFFLINE_MODE" = false ]; then
    echo ""
    echo -e "${AZUL}ℹ️  Instalando colecciones de Ansible...${NC}"
    ansible-galaxy collection install -r "$SCRIPT_DIR/requirements.yml" --force 2>/dev/null || true
fi

echo ""

# Configurar modo offline si es necesario
if [ "$OFFLINE_MODE" = true ]; then
    echo -e "${AZUL}ℹ️  Modo offline activado${NC}"
    
    # Buscar código fuente
    if [ -d "$SCRIPT_DIR/whisper.cpp" ]; then
        export WHISPER_OFFLINE=true
        export WHISPER_OFFLINE_SOURCE="$SCRIPT_DIR/whisper.cpp"
        echo -e "${VERDE}✓ Código fuente encontrado: $SCRIPT_DIR/whisper.cpp${NC}"
    elif [ -d "$SCRIPT_DIR/../.." ] && [ -f "$SCRIPT_DIR/../../CMakeLists.txt" ]; then
        # Estamos dentro del repositorio whisper.cpp
        export WHISPER_OFFLINE=true
        export WHISPER_OFFLINE_SOURCE="$(cd "$SCRIPT_DIR/../.." && pwd)"
        echo -e "${VERDE}✓ Código fuente encontrado: $WHISPER_OFFLINE_SOURCE${NC}"
    else
        echo -e "${ROJO}❌ No se encontró el código fuente de whisper.cpp${NC}"
        echo "   Coloca el directorio 'whisper.cpp' junto a este script"
        exit 1
    fi
    
    # Buscar modelo
    if [ -f "$SCRIPT_DIR/ggml-base.bin" ]; then
        export WHISPER_OFFLINE_MODEL="$SCRIPT_DIR/ggml-base.bin"
        echo -e "${VERDE}✓ Modelo encontrado: ggml-base.bin${NC}"
    elif [ -f "$SCRIPT_DIR/ggml-tiny.bin" ]; then
        export WHISPER_OFFLINE_MODEL="$SCRIPT_DIR/ggml-tiny.bin"
        echo -e "${VERDE}✓ Modelo encontrado: ggml-tiny.bin${NC}"
    else
        echo -e "${AMARILLO}⚠ No se encontró modelo. Se intentará descargar (requiere internet)${NC}"
    fi
    echo ""
fi

# Ejecutar playbook
echo -e "${AZUL}ℹ️  Iniciando compilación e instalación...${NC}"
echo -e "${AMARILLO}   Esto puede tardar varios minutos dependiendo del hardware.${NC}"
echo ""

cd "$SCRIPT_DIR"
ansible-playbook -i inventory.ini build-site.yml --connection=local --ask-become-pass

echo ""
echo -e "${VERDE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${VERDE}║          ¡Instalación completada! 🎉                         ║${NC}"
echo -e "${VERDE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Para empezar a usar whisper:"
echo ""
echo "  1. Reinicia tu terminal o ejecuta:"
echo -e "     ${CYAN}source ~/.bashrc${NC}"
echo ""
echo "  2. Prueba el comando:"
echo -e "     ${CYAN}whisper ayuda${NC}"
echo ""
echo "  3. Transcribe tu primer audio:"
echo -e "     ${CYAN}whisper transcribir mi_audio.wav --idioma es${NC}"
echo ""
