#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/detect-pkg.sh"

echo -e "${RED}>> Iniciando desinstalación de eaSway...${NC}"

map_package() {
    local generic="$1"
    local os_family="${OS_FAMILY:-debian}"
    case "$generic" in
        mako)
            [ "$os_family" = "debian" ] && echo "mako-notifier" || echo "mako" ;;
        *)  echo "$generic" ;;
    esac
}

# =================================================================
# 1. LISTA DE PAQUETES A REMOVER
# =================================================================
PKGS_GENERIC=(
    "sway" "waybar" "rofi" "mako" "xwayland"
    "swaybg" "swayidle" "swaylock" "grim" "slurp"
    "light" "pavucontrol"
)

PKGS=()
for pkg in "${PKGS_GENERIC[@]}"; do
    PKGS+=("$(map_package "$pkg")")
done

if [ ${#PKGS[@]} -gt 0 ]; then
    echo ">> Iniciando purga de paquetes..."
    case "$PKG_MANAGER" in
        apt)    sudo apt purge -yq "${PKGS[@]}" ;;
        pacman) sudo pacman -Rs --noconfirm "${PKGS[@]}" ;;
        dnf)    sudo dnf remove -y "${PKGS[@]}" ;;
    esac
    eval "$PKG_CLEAN" || true
fi

# =================================================================
# 2. RESTAURACIÓN DE BACKUPS
# =================================================================
echo -e " - Restaurando backups de .config..."
CONFIG_DIR="$HOME/.config"
APPS=("sway" "waybar" "mako" "rofi" "foot")

for APP in "${APPS[@]}"; do
    rm -rf "${CONFIG_DIR:?}/${APP:?}"
    LATEST_BAK=$(find "$CONFIG_DIR" -maxdepth 1 -type d -name "${APP}_bak_*" 2>/dev/null | sort -r | head -n 1)
    if [ -n "$LATEST_BAK" ]; then
        mv "$LATEST_BAK" "$CONFIG_DIR/$APP"
        echo -e "${GREEN}[OK]${NC} Restaurado backup para $APP"
    else
        echo -e "   [i] No se encontró backup para $APP, omitiendo."
    fi
done

echo -e "${GREEN}>> Limpieza completada.${NC}"
