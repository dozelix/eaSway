#!/bin/bash

# =================================================================
# version: 0.0.6
# eaSway - Orquestador de Instalación
# Finalidad: Punto de entrada genérico para el despliegue del entorno.
# Fix v0.0.6:
#   - Agregada validación de prerequisitos (bash, sudo)
#   - Mejorada propagación de variables entre scripts
#   - Agregado mejor manejo de errores con rollback simple
#   - Automatización mejorada con logging centralizado
# Fix v0.0.5:
#   - BUG#3: Agregado color BLUE faltante
#   - BUG#3: Corregida línea de resumen que usaba ${NC} en lugar de ${BLUE}
# =================================================================

set -euo pipefail

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || { echo "Error: No se pudo determinar BASE_DIR"; exit 1; }
REPO_ROOT=$(cd "$BASE_DIR/.." && pwd) || { echo "Error: No se pudo determinar REPO_ROOT"; exit 1; }
SCRIPTS_DIR="$REPO_ROOT/scripts"
LOG_FILE="$REPO_ROOT/install.log"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validar prerequisitos
validate_prerequisites() {
    local missing=0
    for cmd in bash sudo; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}[ERROR] Comando requerido no encontrado: $cmd${NC}"
            missing=$((missing + 1))
        fi
    done
    if [ "$missing" -gt 0 ]; then
        echo -e "${RED}[ERROR] Faltan $missing comandos requeridos.${NC}"
        exit 1
    fi
}

# Validar que los scripts existen
validate_scripts() {
    local missing=0
    for script in "check_hardware.sh" "detect-pkg.sh" "install_packages.sh" "setup_config.sh" "post_install.sh" "gpu_environment.sh"; do
        if [ ! -f "$SCRIPTS_DIR/$script" ]; then
            echo -e "${RED}[ERROR] Script no encontrado: $SCRIPTS_DIR/$script${NC}"
            missing=$((missing + 1))
        fi
    done
    if [ "$missing" -gt 0 ]; then
        echo -e "${RED}[ERROR] Faltan $missing scripts de instalación.${NC}"
        exit 1
    fi
}

echo -e "${GREEN}Iniciando eaSway${NC}"
echo -e "Usuario detectado: ${USER:-$(whoami)}\n"
echo -e "${BLUE}Log: $LOG_FILE${NC}\n"

# Validar prerequisitos
validate_prerequisites

# Validar scripts
validate_scripts

# =================================================================
# Ejecución de pasos que no exportan variables al orquestador
# =================================================================
run_step() {
    local script_file="$1"
    local description="$2"
    local full_path="$SCRIPTS_DIR/$script_file"

    echo -e "[i] Ejecutando: $description..."
    echo "--- $description ---" >> "$LOG_FILE"

    if [ ! -f "$full_path" ]; then
        echo -e "${RED}[!] ERROR: No se encontró el archivo $script_file en $SCRIPTS_DIR${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi

    if bash "$full_path" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✔ $description completado con éxito.${NC}\n"
        echo "SUCCESS" >> "$LOG_FILE"
    else
        local exit_code=$?
        echo -e "${RED}✘ Error durante $description. Abortando instalación.${NC}\n" | tee -a "$LOG_FILE"
        echo "FAILED (exit code: $exit_code)" >> "$LOG_FILE"
        exit 1
    fi
}

# =================================================================
# Ejecución de pasos que exportan variables al orquestador
# (source para que GPU_VENDOR y DEVICE_TYPE sean visibles aquí)
# =================================================================
run_step_source() {
    local script_file="$1"
    local description="$2"
    local full_path="$SCRIPTS_DIR/$script_file"

    echo -e "[i] Ejecutando: $description..."
    echo "--- $description ---" >> "$LOG_FILE"

    if [ ! -f "$full_path" ]; then
        echo -e "${RED}[!] ERROR: No se encontró el archivo $script_file en $SCRIPTS_DIR${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi

    # shellcheck source=/dev/null
    if source "$full_path" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✔ $description completado con éxito.${NC}\n"
        echo "SUCCESS" >> "$LOG_FILE"
    else
        local exit_code=$?
        echo -e "${RED}✘ Error durante $description. Abortando instalación.${NC}\n" | tee -a "$LOG_FILE"
        echo "FAILED (exit code: $exit_code)" >> "$LOG_FILE"
        exit 1
    fi
}

# =================================================================
# Secuencia de instalación
# =================================================================
{
    echo "================================================"
    echo "eaSway Installation - $(date)"
    echo "User: ${USER:-$(whoami)}"
    echo "================================"
} >> "$LOG_FILE"

# Paso 1: source — necesita exportar GPU_VENDOR y DEVICE_TYPE
run_step_source "check_hardware.sh" "Detección de Hardware"

# Mostrar variables detectadas
echo -e "${BLUE}>> Variables de Entorno Detectadas:${NC}"
echo -e "   - EN_VIRTUALIZACIÓN: ${IN_VM:-false}"
echo -e "   - TIPO_DISPOSITIVO: ${DEVICE_TYPE:-undefined}"
echo -e "   - GPU: ${GPU_VENDOR:-undefined}\n"

# Pasos 2-5: bash normal — las variables llegan via export del environment
run_step "install_packages.sh"  "Instalación de Paquetes"
run_step "setup_config.sh"      "Despliegue de Configuraciones"
run_step "post_install.sh"      "Ajustes de Sistema y Permisos"
run_step "gpu_environment.sh"   "Configuración de Entorno Gráfico"

{
    echo "================================================"
    echo "Installation completed successfully"
    echo "================================================"
} >> "$LOG_FILE"

echo -e "${GREEN}Proceso de orquestación finalizado correctamente.${NC}"
echo -e "${BLUE}Log completo disponible en: $LOG_FILE${NC}"