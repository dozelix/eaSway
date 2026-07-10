#!/bin/bash
set -euo pipefail

BASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ORCHESTRATOR="$BASE_DIR/scripts/orchestrator.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ensure_sudo_cached() {
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}[OK] Credenciales sudo en caché.${NC}"
        return 0
    fi

    echo -e "${YELLOW}[i] Se requiere permiso de administrador. Solicitando credenciales sudo...${NC}"
    if sudo -v; then
        echo -e "${GREEN}[OK] Credenciales sudo obtenidas.${NC}"
    else
        echo -e "${RED}[ERROR] No se pudo obtener credenciales sudo.${NC}"
        exit 1
    fi
}

if [ ! -f "$ORCHESTRATOR" ]; then
    echo -e "${RED}[ERROR] Orquestador no encontrado en: $ORCHESTRATOR${NC}"
    exit 1
fi

ensure_sudo_cached
exec bash "$ORCHESTRATOR" "$@"
