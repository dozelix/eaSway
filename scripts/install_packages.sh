#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =================================================================
# 1. DETECTAR GESTOR DE PAQUETES
# =================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/detect-pkg.sh"

# =================================================================
# 2. VALIDACIÓN DE VARIABLES CRÍTICAS
# =================================================================
if [ -z "${DEVICE_TYPE:-}" ]; then
    echo -e "${YELLOW}[!] DEVICE_TYPE no definido. Usando 'desktop' por defecto.${NC}"
    export DEVICE_TYPE="desktop"
fi

if [ -z "${GPU_VENDOR:-}" ]; then
    echo -e "${YELLOW}[!] GPU_VENDOR no definido. Usando 'Desconocido' por defecto.${NC}"
    export GPU_VENDOR="Desconocido"
fi

if [ -z "${IN_VM:-}" ]; then
    export IN_VM=false
fi

echo -e "${BLUE}   - Dispositivo: $DEVICE_TYPE${NC}"
echo -e "${BLUE}   - GPU: $GPU_VENDOR${NC}"
echo -e "${BLUE}   - En VM: $IN_VM${NC}"
echo -e "${BLUE}   - Sistema: $OS_FAMILY (via $PKG_MANAGER)${NC}\n"

# =================================================================
# 3. MAPA DE PAQUETES POR DISTRO
# =================================================================
# Formato: nombre_genérico -> ["debian", "arch", "fedora"]
map_package() {
    local generic="$1"
    case "$generic" in
        # Wayland core
        wayland-protocols)
            case "$OS_FAMILY" in
                debian) echo "wayland-protocols" ;;
                arch) echo "wayland-protocols" ;;
                fedora) echo "wayland-protocols-devel" ;;
            esac ;;
        xwayland)
            case "$OS_FAMILY" in
                debian) echo "xwayland" ;;
                arch) echo "xorg-xwayland" ;;
                fedora) echo "xorg-xwayland" ;;
            esac ;;
        mesa-utils)
            case "$OS_FAMILY" in
                debian) echo "mesa-utils" ;;
                arch) echo "mesa-utils" ;;
                fedora) echo "mesa-utils" ;;
            esac ;;
        # Sway core
        sway)
            case "$OS_FAMILY" in
                debian) echo "sway" ;;
                arch) echo "sway" ;;
                fedora) echo "sway" ;;
            esac ;;
        waybar)
            case "$OS_FAMILY" in
                debian) echo "waybar" ;;
                arch) echo "waybar" ;;
                fedora) echo "waybar" ;;
            esac ;;
        rofi)
            case "$OS_FAMILY" in
                debian) echo "rofi" ;;
                arch) echo "rofi" ;;
                fedora) echo "rofi" ;;
            esac ;;
        mako)
            case "$OS_FAMILY" in
                debian) echo "mako-notifier" ;;
                arch) echo "mako" ;;
                fedora) echo "mako" ;;
            esac ;;
        seatd)
            case "$OS_FAMILY" in
                debian) echo "seatd" ;;
                arch) echo "seatd" ;;
                fedora) echo "seatd" ;;
            esac ;;
        # Utilidades
        swaybg)
            case "$OS_FAMILY" in
                debian) echo "swaybg" ;;
                arch) echo "swaybg" ;;
                fedora) echo "swaybg" ;;
            esac ;;
        swayidle)
            case "$OS_FAMILY" in
                debian) echo "swayidle" ;;
                arch) echo "swayidle" ;;
                fedora) echo "swayidle" ;;
            esac ;;
        swaylock)
            case "$OS_FAMILY" in
                debian) echo "swaylock" ;;
                arch) echo "swaylock" ;;
                fedora) echo "swaylock" ;;
            esac ;;
        grim)
            case "$OS_FAMILY" in
                debian) echo "grim" ;;
                arch) echo "grim" ;;
                fedora) echo "grim" ;;
            esac ;;
        slurp)
            case "$OS_FAMILY" in
                debian) echo "slurp" ;;
                arch) echo "slurp" ;;
                fedora) echo "slurp" ;;
            esac ;;
        light)
            case "$OS_FAMILY" in
                debian) echo "light" ;;
                arch) echo "light" ;;
                fedora) echo "light" ;;
            esac ;;
        pavucontrol)
            case "$OS_FAMILY" in
                debian) echo "pavucontrol" ;;
                arch) echo "pavucontrol" ;;
                fedora) echo "pavucontrol" ;;
            esac ;;
        nm-applet)
            case "$OS_FAMILY" in
                debian) echo "network-manager-gnome" ;;
                arch) echo "network-manager-applet" ;;
                fedora) echo "network-manager-applet" ;;
            esac ;;
        thunar)
            case "$OS_FAMILY" in
                debian) echo "thunar" ;;
                arch) echo "thunar" ;;
                fedora) echo "thunar" ;;
            esac ;;
        foot)
            case "$OS_FAMILY" in
                debian) echo "foot" ;;
                arch) echo "foot" ;;
                fedora) echo "foot" ;;
            esac ;;
        # EGL / Mesa (Debian varía por versión)
        libegl)
            OS_VER="${OS_VER:-}"
            case "$OS_FAMILY" in
                debian)
                    case "$OS_VER" in
                        12|22.04) echo "libegl1-mesa" ;;
                        *) echo "libegl1" ;;
                    esac ;;
                arch) echo "libgl" ;;
                fedora) echo "mesa-libEGL" ;;
            esac ;;
        libgl-dri)
            case "$OS_FAMILY" in
                debian) echo "libgl1-mesa-dri" ;;
                arch) echo "libgl" ;;
                fedora) echo "mesa-dri-drivers" ;;
            esac ;;
        libwayland-egl)
            case "$OS_FAMILY" in
                debian) echo "libwayland-egl1" ;;
                arch) echo "libwayland" ;;
                fedora) echo "libwayland-egl" ;;
            esac ;;
        # GPU-specific
        intel-media)
            case "$OS_FAMILY" in
                debian) echo "intel-media-va-driver" ;;
                arch) echo "intel-media-driver" ;;
                fedora) echo "intel-media-driver" ;;
            esac ;;
        mesa-va)
            case "$OS_FAMILY" in
                debian) echo "mesa-va-drivers" ;;
                arch) echo "libva-mesa-driver" ;;
                fedora) echo "libva-mesa-driver" ;;
            esac ;;
        # Laptop utilities
        tlp)
            case "$OS_FAMILY" in
                debian) echo "tlp" ;;
                arch) echo "tlp" ;;
                fedora) echo "tlp" ;;
            esac ;;
        brightnessctl)
            case "$OS_FAMILY" in
                debian) echo "brightnessctl" ;;
                arch) echo "brightnessctl" ;;
                fedora) echo "brightnessctl" ;;
            esac ;;
        libinput)
            case "$OS_FAMILY" in
                debian) echo "libinput-tools" ;;
                arch) echo "libinput" ;;
                fedora) echo "libinput" ;;
            esac ;;
        *)
            echo "$generic"
            ;;
    esac
}

# =================================================================
# 4. DEFINICIÓN DE PAQUETES POR PRIORIDAD (nombres genéricos)
# =================================================================
WAYLAND_CORE_GENERIC=("wayland-protocols" "libwayland-egl" "mesa-utils" "xwayland")

# Agregar EGL y DRI según el OS
WAYLAND_CORE_GENERIC+=("libegl" "libgl-dri")

echo -e "[i] Instalando para $OS_FAMILY (via $PKG_MANAGER)"

# Resolver nombres reales
WAYLAND_CORE=()
for pkg in "${WAYLAND_CORE_GENERIC[@]}"; do
    WAYLAND_CORE+=("$(map_package "$pkg")")
done

CRITICAL_PKGS_GENERIC=("sway" "waybar" "rofi" "mako" "seatd")
CRITICAL_PKGS=()
for pkg in "${CRITICAL_PKGS_GENERIC[@]}"; do
    CRITICAL_PKGS+=("$(map_package "$pkg")")
done

UTILITY_PKGS_GENERIC=("swaybg" "swayidle" "swaylock" "grim" "slurp" "light" "pavucontrol" "nm-applet" "thunar" "foot")
UTILITY_PKGS=()
for pkg in "${UTILITY_PKGS_GENERIC[@]}"; do
    UTILITY_PKGS+=("$(map_package "$pkg")")
done

if [ "$DEVICE_TYPE" = "laptop" ]; then
    UTILITY_PKGS_GENERIC+=("tlp" "brightnessctl" "libinput")
    UTILITY_PKGS+=("$(map_package "tlp")" "$(map_package "brightnessctl")" "$(map_package "libinput")")
fi

echo -e "[i] Paquetes: ${WAYLAND_CORE[*]} ${CRITICAL_PKGS[*]} ${UTILITY_PKGS[*]}"

# =================================================================
# 5. PAQUETES CONDICIONALES POR GPU
# =================================================================
add_gpu_packages() {
    local vendor="$1"
    case "$vendor" in
        "Intel")
            UTILITY_PKGS+=("$(map_package "intel-media")")
            echo -e "${BLUE}   [i] GPU Intel: agregando $(map_package "intel-media").${NC}"
            ;;
        "AMD")
            UTILITY_PKGS+=("$(map_package "mesa-va")")
            echo -e "${BLUE}   [i] GPU AMD: agregando $(map_package "mesa-va").${NC}"
            ;;
        "NVIDIA")
            echo -e "${YELLOW}   [!] GPU NVIDIA: drivers propietarios requieren instalación manual.${NC}"
            ;;
        *)
            echo -e "${YELLOW}   [?] GPU desconocida. Saltando paquetes específicos de GPU.${NC}"
            ;;
    esac
}

if [ -n "${GPU_VENDOR:-}" ]; then
    add_gpu_packages "$GPU_VENDOR"
fi

# =================================================================
# 6. ACTUALIZACIÓN DE REPOSITORIOS
# =================================================================
echo -e "${YELLOW}>> Verificando estado de repositorios...${NC}"

if [ "$PKG_MANAGER" = "apt" ]; then
    if [ ! -f /var/lib/apt/periodic/update-success-stamp ]; then
        last_update=0
    else
        last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp 2>/dev/null) || last_update=0
    fi
    now=$(date +%s) || now=0

    if [ $((now - last_update)) -gt 86400 ]; then
        echo -e "   [i] Repositorios con más de 24h. Actualizando..."
        if ! eval "$PKG_UPDATE"; then
            echo -e "${RED}   [ERROR] Falló $PKG_UPDATE. Verifica tu conexión.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}   [OK] Repositorios actualizados recientemente.${NC}"
    fi
else
    eval "$PKG_UPDATE"
fi

# =================================================================
# 7. INSTALACIÓN DE COMPONENTES (ordenada por prioridad)
# =================================================================
install_group() {
    local desc="$1"
    shift
    local pkgs=("$@")
    echo -e "${YELLOW}>> $desc${NC}"
    if eval "$PKG_INSTALL" "${pkgs[@]}"; then
        echo -e "${GREEN}   [OK] $desc completada.${NC}"
    else
        echo -e "${RED}   [ERROR] Falló $desc. Abortando.${NC}"
        exit 1
    fi
}

install_group "Instalando protocolos y drivers de Wayland" "${WAYLAND_CORE[@]}"
install_group "Instalando componentes críticos de Sway" "${CRITICAL_PKGS[@]}"

echo -e "${YELLOW}>> Instalando utilidades y extras...${NC}"
if eval "$PKG_INSTALL" "${UTILITY_PKGS[@]}"; then
    echo -e "${GREEN}   [OK] Utilidades instaladas correctamente.${NC}"
else
    echo -e "${YELLOW}   [!] Algunos paquetes opcionales fallaron. Revisa los logs.${NC}"
fi

# =================================================================
# 8. LIMPIEZA FINAL
# =================================================================
echo -e "${YELLOW}>> Limpiando caché...${NC}"
eval "$PKG_CLEAN" || true

# =================================================================
# 9. CONFIGURACIÓN DE USUARIO Y GRUPOS
# =================================================================
echo -e "${YELLOW}>> Configurando permisos de usuario...${NC}"

TARGET_USER="${SUDO_USER:-${USER:-dozelix}}"
echo -e "   [i] Usuario objetivo: '${TARGET_USER}'"

if id "$TARGET_USER" &>/dev/null; then
    if sudo usermod -aG video,input "$TARGET_USER"; then
        echo -e "${GREEN}   [OK] '${TARGET_USER}' añadido a grupos video e input.${NC}"
    else
        echo -e "${RED}   [ERROR] Falló usermod para '${TARGET_USER}'.${NC}"
    fi
else
    echo -e "${YELLOW}   [!] Usuario '${TARGET_USER}' no encontrado.${NC}"
fi

# =================================================================
# 10. PERMISOS PARA CONTROL DE BRILLO
# =================================================================
if [ "$IN_VM" = false ] && command -v light > /dev/null; then
    echo -e "   [i] Configurando SUID para 'light'..."
    if sudo chmod +s "$(command -v light)" 2>/dev/null; then
        echo -e "${GREEN}   [OK] Permisos de brillo configurados.${NC}"
    else
        echo -e "${YELLOW}   [!] No se pudo configurar SUID para 'light'.${NC}"
    fi
elif [ "$IN_VM" = true ]; then
    echo -e "${YELLOW}   [i] Virtualización detectada. Saltando SUID para 'light'.${NC}"
fi

# =================================================================
# 11. ACTIVACIÓN DE SERVICIOS
# =================================================================
echo -e "${YELLOW}>> Verificando gestor de servicios...${NC}"

if pidof systemd > /dev/null 2>&1 || [ -d /run/systemd/system ]; then
    echo -e "   [i] systemd detectado. Activando NetworkManager..."
    if sudo systemctl enable --now NetworkManager 2>/dev/null; then
        echo -e "${GREEN}   [OK] NetworkManager activado.${NC}"
    else
        echo -e "${YELLOW}   [!] No se pudo activar NetworkManager (esperado en algunas VMs).${NC}"
    fi
else
    echo -e "${YELLOW}   [!] systemd NO disponible. Saltando activación de servicios.${NC}"
fi

echo -e "${GREEN}>> Instalación de paquetes completada.${NC}"
