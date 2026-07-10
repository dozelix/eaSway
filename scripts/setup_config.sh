#!/bin/bash
set -euo pipefail

# =================================================================
# Versión: 0.1
# eaSway - Módulo de Configuración de Dotfiles
# Finalidad: Instalar configuraciones con seguridad de backups.
# =================================================================
#def var array apps
APPS=(
    "sway"
    "waybar"
    "mako"
    "rofi"
    "foot"
)
# def Colores
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# 1. def Rutas (Subimos un nivel desde /scripts para hallar la raíz)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)" || { echo -e "${RED}[ERROR] No se pudo determinar REPO_ROOT.${NC}"; exit 1; }
DOTFILES_DIR="$REPO_ROOT/dotfiles"
TARGET_DIR="$HOME/.config"

echo -e "${CYAN}>> Desplegando configuraciones de eaSway...${NC}"

# 2. Validación de Espacio en Disco (Mínimo 50MB para backups)
AVAILABLE_SPACE=$(df "$HOME" 2>/dev/null | awk 'NR==2 {print $4}') || AVAILABLE_SPACE=0
if [ "$AVAILABLE_SPACE" -lt 51200 ]; then
    echo -e "${RED}[ERROR] Espacio insuficiente en HOME para realizar backups.${NC}"
    exit 1
fi

for APP in "${APPS[@]}"; do
    SRC="$DOTFILES_DIR/$APP"
    DEST="$TARGET_DIR/$APP"

    if [ -d "$SRC" ]; then
        # Crear backup si ya existe la carpeta de destino
        if [ -d "$DEST" ]; then
            BACKUP_PATH="${DEST}_bak_$(date +%Y%m%d_%H%M%S)"
            mv "$DEST" "$BACKUP_PATH" || { echo -e "${RED}   [!] Falló backup para $APP.${NC}"; exit 1; }
            echo -e "   - Backup creado: $APP -> $(basename "$BACKUP_PATH")"
        fi

        # Instalación limpia
        mkdir -p "$DEST"
        cp -r "$SRC/." "$DEST/"
        echo -e "${GREEN}   [OK] Configuración de $APP instalada.${NC}"
    else
        echo -e "${RED}   [!] Advertencia: No hay archivos para $APP en el repo.${NC}"
    fi
done

echo -e "${CYAN}>> Proceso de configuración terminado.${NC}"