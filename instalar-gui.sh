#!/bin/bash
# ============================================================================
# Instalador de Whisper con Interfaz Gráfica
# Una forma fácil de instalar whisper.cpp con una GUI amigable
# ============================================================================

set -e

# Colores
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

mostrar_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   ██╗    ██╗██╗  ██╗██╗███████╗██████╗ ███████╗██████╗        ║"
    echo "║   ██║    ██║██║  ██║██║██╔════╝██╔══██╗██╔════╝██╔══██╗       ║"
    echo "║   ██║ █╗ ██║███████║██║███████╗██████╔╝█████╗  ██████╔╝       ║"
    echo "║   ██║███╗██║██╔══██║██║╚════██║██╔═══╝ ██╔══╝  ██╔══██╗       ║"
    echo "║   ╚███╔███╔╝██║  ██║██║███████║██║     ███████╗██║  ██║       ║"
    echo "║    ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝       ║"
    echo "║                                                               ║"
    echo "║        Instalador con Interfaz Gráfica 🎤➜📝🖥️                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

info() {
    echo -e "${AZUL}ℹ️  $1${NC}"
}

exito() {
    echo -e "${VERDE}✅ $1${NC}"
}

advertencia() {
    echo -e "${AMARILLO}⚠️  $1${NC}"
}

error() {
    echo -e "${ROJO}❌ $1${NC}"
    exit 1
}

verificar_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        advertencia "Ansible no está instalado."
        echo ""
        echo "Instalando Ansible automáticamente..."
        
        # Detectar distribución e instalar Ansible
        if command -v dnf &> /dev/null; then
            sudo dnf install -y ansible
        elif command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y ansible
        elif command -v pacman &> /dev/null; then
            sudo pacman -Sy --noconfirm ansible
        elif command -v zypper &> /dev/null; then
            sudo zypper install -y ansible
        else
            error "No se pudo detectar el gestor de paquetes. Instala Ansible manualmente."
        fi
        
        exito "Ansible instalado"
    else
        exito "Ansible encontrado"
    fi
}

main() {
    mostrar_banner
    
    echo ""
    info "Este instalador configurará:"
    echo "  • whisper.cpp para transcripción de audio"
    echo "  • Interfaz gráfica fácil de usar"
    echo "  • Conversión automática de formatos de audio"
    echo "  • Modelo base de IA (~142MB)"
    echo ""
    
    # Verificar que estamos en el directorio correcto
    if [ ! -f "gui-install.yml" ]; then
        error "Ejecuta este script desde el directorio del instalador (donde está gui-install.yml)"
    fi
    
    # Verificar Ansible
    info "Verificando requisitos..."
    verificar_ansible
    
    echo ""
    info "Iniciando instalación..."
    info "Se te pedirá tu contraseña para instalar dependencias del sistema."
    echo ""
    
    # Ejecutar playbook
    ansible-playbook -i inventory.ini gui-install.yml --ask-become-pass
    
    echo ""
    echo -e "${VERDE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              ¡Instalación completada! 🎉                      ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║                                                               ║"
    echo "║  CÓMO USAR:                                                   ║"
    echo "║                                                               ║"
    echo "║  1. Busca 'Whisper Transcriptor' en el menú de aplicaciones   ║"
    echo "║                                                               ║"
    echo "║  2. O ejecuta desde la terminal:                              ║"
    echo "║     whisper-gui                                               ║"
    echo "║                                                               ║"
    echo "║  NOTA: Puede que necesites cerrar sesión y volver a entrar    ║"
    echo "║        para que aparezca en el menú de aplicaciones.          ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

main "$@"
