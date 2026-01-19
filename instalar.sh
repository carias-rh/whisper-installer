#!/bin/bash
# ============================================================================
# Script de instalación rápida de whisper.cpp
# Ejecutar con: ./instalar.sh
# ============================================================================

set -e

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
NC='\033[0m'

echo -e "${AZUL}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║        Instalador de whisper.cpp con Ansible         ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar Ansible
if ! command -v ansible &> /dev/null; then
    echo -e "${AMARILLO}⚠️  Ansible no está instalado.${NC}"
    echo ""
    
    # Detectar distribución
    if [ -f /etc/fedora-release ]; then
        echo "Detectado: Fedora"
        echo -e "${AZUL}Instalando Ansible...${NC}"
        sudo dnf install -y ansible
    elif [ -f /etc/debian_version ]; then
        echo "Detectado: Debian/Ubuntu"
        echo -e "${AZUL}Instalando Ansible...${NC}"
        sudo apt update && sudo apt install -y ansible
    elif [ -f /etc/arch-release ]; then
        echo "Detectado: Arch Linux"
        echo -e "${AZUL}Instalando Ansible...${NC}"
        sudo pacman -S --noconfirm ansible
    else
        echo -e "${ROJO}❌ No se pudo detectar la distribución.${NC}"
        echo "Por favor, instala Ansible manualmente:"
        echo "  pip install ansible"
        exit 1
    fi
fi

echo -e "${VERDE}✓ Ansible disponible${NC}"
echo ""

# Instalar colección de Podman
echo -e "${AZUL}Instalando colección de Podman para Ansible...${NC}"
ansible-galaxy collection install -r requirements.yml --force 2>/dev/null || true
echo -e "${VERDE}✓ Colecciones instaladas${NC}"
echo ""

# Cambiar al directorio del script
cd "$(dirname "$0")"

# Preguntar tipo de instalación
echo -e "${AMARILLO}¿Dónde quieres instalar whisper.cpp?${NC}"
echo ""
echo "  1) En esta máquina (local)"
echo "  2) En un servidor remoto"
echo ""
read -p "Selecciona una opción [1]: " opcion

opcion=${opcion:-1}

case "$opcion" in
    1)
        echo ""
        echo -e "${AZUL}Instalando localmente...${NC}"
        echo -e "${AMARILLO}Solo se pedirá sudo para instalar Podman (si no está instalado).${NC}"
        echo ""
        ansible-playbook -i inventory.ini site.yml --connection=local --ask-become-pass
        ;;
    2)
        echo ""
        read -p "Introduce la IP o hostname del servidor: " servidor
        read -p "Introduce el usuario SSH: " usuario
        echo ""
        
        # Crear inventario temporal
        echo "[whisper_servers]" > /tmp/whisper_inventory.ini
        echo "$servidor ansible_user=$usuario" >> /tmp/whisper_inventory.ini
        
        echo -e "${AZUL}Instalando en $servidor...${NC}"
        echo -e "${AMARILLO}Solo se pedirá sudo para instalar Podman (si no está instalado).${NC}"
        ansible-playbook -i /tmp/whisper_inventory.ini site.yml --ask-pass --ask-become-pass
        
        rm -f /tmp/whisper_inventory.ini
        ;;
    *)
        echo -e "${ROJO}Opción no válida${NC}"
        exit 1
        ;;
esac

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
