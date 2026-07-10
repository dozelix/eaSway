#!/bin/bash
set -euo pipefail

detect_package_manager() {
    if command -v apt &>/dev/null; then
        export PKG_MANAGER="apt"
        export PKG_INSTALL="DEBIAN_FRONTEND=noninteractive sudo apt install -yq"
        export PKG_INSTALL_NO_DEPS="DEBIAN_FRONTEND=noninteractive sudo apt install -yq --no-install-recommends"
        export PKG_UPDATE="DEBIAN_FRONTEND=noninteractive sudo apt update"
        export PKG_REMOVE="sudo apt purge -yq"
        export PKG_CLEAN="DEBIAN_FRONTEND=noninteractive sudo apt autoremove -yq && DEBIAN_FRONTEND=noninteractive sudo apt autoclean"
        export PKG_UPGRADE="DEBIAN_FRONTEND=noninteractive sudo apt upgrade -yq"
        export PKG_QUERY="dpkg -l"
        export OS_FAMILY="debian"
    elif command -v pacman &>/dev/null; then
        export PKG_MANAGER="pacman"
        export PKG_INSTALL="sudo pacman -S --needed --noconfirm"
        export PKG_INSTALL_NO_DEPS="sudo pacman -S --needed --noconfirm"
        export PKG_UPDATE="sudo pacman -Sy"
        export PKG_REMOVE="sudo pacman -Rs --noconfirm"
        export PKG_CLEAN="sudo pacman -Sc --noconfirm"
        export PKG_UPGRADE="sudo pacman -Syu --noconfirm"
        export PKG_QUERY="pacman -Q"
        export OS_FAMILY="arch"
    elif command -v dnf &>/dev/null; then
        export PKG_MANAGER="dnf"
        export PKG_INSTALL="sudo dnf install -y"
        export PKG_INSTALL_NO_DEPS="sudo dnf install -y --setopt=install_weak_deps=False"
        export PKG_UPDATE="sudo dnf check-update || true"
        export PKG_REMOVE="sudo dnf remove -y"
        export PKG_CLEAN="sudo dnf clean all"
        export PKG_UPGRADE="sudo dnf upgrade -y"
        export PKG_QUERY="rpm -q"
        export OS_FAMILY="fedora"
    else
        echo -e "${RED}[ERROR] No se detectó un gestor de paquetes compatible (apt/pacman/dnf).${NC}"
        exit 1
    fi

    echo -e "${GREEN}   [OK] Gestor detectado: $PKG_MANAGER (familia: $OS_FAMILY)${NC}"
}

detect_package_manager
