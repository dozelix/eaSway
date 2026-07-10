#!/bin/bash
set -euo pipefail

# =================================================================
# Versión: 0.0.4-alpha
# eaSway - Módulo de Detección de Hardware
# Finalidad: Verificar el entorno antes de la instalación.
# Fix v0.0.4-alpha (AUDIT_TRACE_V3):
#   - T05 FIX: DMI-first virtualization check (prevents iGPU false positives)
#   - T06 FIX: Kernel module validation for real GPU detection
#   - En VM/Docker: exportar GPU_VENDOR="Desconocido" y
#     DEVICE_TYPE="desktop" antes de salir, para que los módulos
#     siguientes tengan las variables disponibles.
#   - VM ya no aborta el instalador — solo advierte.
# =================================================================

YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

WARNINGS=0

echo -e "${BLUE}>> Iniciando verificación de hardware...${NC}"
echo -e "   ----------------------------------------"

# =================================================================
# 1. DETECCIÓN DE VIRTUALIZACIÓN (Docker, KVM, VirtualBox, etc.)
# =================================================================
IS_VM=false
export IN_VM=false
SKIP_HARDWARE_DETECTION=false

# T05 FIX: Verify physical hardware via DMI before assuming virtualization
# Prioritize /sys/class/dmi/id/board_vendor over systemd-detect-virt to avoid
# false positives when iGPU drivers load generic VGA modules.
is_physical_hardware() {
    if [ -f /sys/class/dmi/id/board_vendor ]; then
        local vendor=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null)
        if [ -n "$vendor" ] && [ "$vendor" != "QEMU" ] && [ "$vendor" != "VMware" ] && [ "$vendor" != "VirtualBox" ]; then
            return 0
        fi
    fi
    return 1
}

# Only trust systemd-detect-virt if DMI doesn't confirm physical hardware
if ! is_physical_hardware; then
    if command -v systemd-detect-virt &>/dev/null; then
        VIRT_ENV=$(systemd-detect-virt 2>/dev/null) || VIRT_ENV="unknown"
        if [ "$VIRT_ENV" != "none" ]; then
            echo -e "${YELLOW}   [!] Entorno virtualizado detectado: $VIRT_ENV${NC}"
            echo -e "${YELLOW}   [!] Sway requiere GPU con soporte DRM/KMS.${NC}"
            echo "[!] En virtualización, Sway requiere aceleración 3D habilitada en la VM."
            IS_VM=true
            export IN_VM=true
            export DEVICE_TYPE="desktop"
            export GPU_VENDOR="Desconocido"
            WARNINGS=$((WARNINGS + 1))
            SKIP_HARDWARE_DETECTION=true
            echo -e "   ----------------------------------------"
            echo -e "${GREEN}>> Virtualización detectada. Exportando configuración por defecto.${NC}"
        fi
    fi
fi

# Si se detectó virtualización, verificar dependencias mínimas y salir.
# BUG-5 FIX: REQUIRED_CMDS estaba DESPUÉS del exit 0, nunca se ejecutaba en VM.
if [ "$SKIP_HARDWARE_DETECTION" = true ]; then
    echo -e "${YELLOW}>> Verificando dependencias mínimas (entorno VM)...${NC}"
    REQUIRED_CMDS=("bash" "sudo" "cp" "mkdir" "find")
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}   [ERROR] Dependencia crítica no encontrada: '$cmd'${NC}"
        fi
    done
    echo -e "   ----------------------------------------"
    echo -e "   - Tipo de dispositivo: $DEVICE_TYPE"
    echo -e "   - Fabricante de GPU: $GPU_VENDOR"
    echo -e "   - En virtualización: $IN_VM"
    echo -e "${GREEN}>> Configuración de virtualización completada.${NC}"
    return 0 2>/dev/null || exit 0
fi

# =================================================================
# 2. ARQUITECTURA DEL SISTEMA
# =================================================================
ARCH=$(uname -m)
echo -e "   - Arquitectura del sistema: ${ARCH}"

if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}   [!] ADVERTENCIA: eaSway está optimizado para x86_64.${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# =================================================================
# 3. DETECCIÓN DE TIPO DE CHASIS (Laptop vs Desktop)
# =================================================================
IS_LAPTOP=false

if [ -f /sys/class/dmi/id/chassis_type ]; then
    CHASSIS_ID=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
    case "$CHASSIS_ID" in
        8|9|10|11|12|14) IS_LAPTOP=true ;;
    esac
fi

if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]; then
    IS_LAPTOP=true
fi

if [ "$IS_LAPTOP" = true ]; then
    export DEVICE_TYPE="laptop"
    echo -e "${GREEN}   [OK] Dispositivo detectado como Laptop.${NC}"
else
    export DEVICE_TYPE="desktop"
    echo -e "   - Dispositivo detectado como Desktop."
fi

# =================================================================
# 4. DETECCIÓN DE GPU
# =================================================================
classify_gpu() {
    local raw="$1"
    if echo "$raw" | grep -qi "nvidia"; then
        echo "NVIDIA"
    elif echo "$raw" | grep -qi "amd\|radeon\|advanced micro"; then
        echo "AMD"
    elif echo "$raw" | grep -qi "intel"; then
        echo "Intel"
    else
        echo "Desconocido"
    fi
}

# T06 FIX: Validate GPU is not virtual by checking kernel module load state.
# Prevents false positives when QEMU/VirtIO GPUs pass through lspci grep.
is_real_gpu() {
    lsmod 2>/dev/null > /tmp/lsmod_check.tmp || return 1
    grep -qE "i915|amdgpu|nouveau|nvidia" /tmp/lsmod_check.tmp && return 0
    return 1
}

if ! command -v lspci &>/dev/null; then
    echo -e "${YELLOW}   [!] 'lspci' no encontrado. No se puede detectar la GPU.${NC}"
    export GPU_VENDOR="Desconocido"
    WARNINGS=$((WARNINGS + 1))
else
    GPU_RAW=$(lspci 2>/dev/null | grep -iE 'vga|display|3d controller' | head -n 1) || GPU_RAW=""
    GPU_NAME="${GPU_RAW#*: }"
    export GPU_VENDOR
    GPU_VENDOR=$(classify_gpu "$GPU_RAW")

    echo -e "   - GPU detectada: ${GPU_NAME:-Desconocida}"

    # If lspci found a GPU but no real driver is loaded, it's likely virtual
    if [ -z "$GPU_RAW" ] || ! is_real_gpu; then
        echo -e "${YELLOW}   [?] GPU virtual o no soportada.${NC}"
        export GPU_VENDOR="Desconocido"
        WARNINGS=$((WARNINGS + 1))
    else
        case "$GPU_VENDOR" in
            "NVIDIA")
                echo -e "${YELLOW}   [!] GPU NVIDIA detectada. Requiere drivers propietarios.${NC}"
                WARNINGS=$((WARNINGS + 1))
                ;;
            "AMD")
                echo -e "${GREEN}   [OK] GPU AMD detectada.${NC}"
                ;;
            "Intel")
                echo -e "${GREEN}   [OK] GPU Intel detectada.${NC}"
                ;;
            *)
                echo -e "${YELLOW}   [?] Fabricante de GPU no identificado.${NC}"
                WARNINGS=$((WARNINGS + 1))
                ;;
        esac
    fi
fi

# =================================================================
# 5. DEPENDENCIAS MÍNIMAS — solo ruta no-VM
# (en ruta VM ya se verificaron antes del exit 0 temprano)
# =================================================================
REQUIRED_CMDS=("bash" "sudo" "cp" "mkdir" "find")
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}   [ERROR] Dependencia crítica no encontrada: '$cmd'${NC}"
    fi
done

# =================================================================
# 6. VALIDACIÓN FINAL DE VARIABLES
# =================================================================
# Asegurar que todas las variables están definidas (fallback)
if [ -z "$DEVICE_TYPE" ]; then
    export DEVICE_TYPE="desktop"
fi

if [ -z "$GPU_VENDOR" ]; then
    export GPU_VENDOR="Desconocido"
fi

if [ -z "$IN_VM" ]; then
    export IN_VM=false
fi

# =================================================================
# 7. RESUMEN FINAL
# =================================================================
echo -e "   ----------------------------------------"
echo -e "   - Tipo de dispositivo: $DEVICE_TYPE"
echo -e "   - Fabricante de GPU: $GPU_VENDOR"
echo -e "   - Entorno VM: $IN_VM"
if [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}>> Verificación completada con $WARNINGS advertencia(s).${NC}"
else
    echo -e "${GREEN}>> Verificación de hardware completada sin problemas.${NC}"
fi

# Determinar si el script fue sourceado o ejecutado directamente.
# shellcheck disable=SC2250
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    return 0
else
    exit 0
fi
