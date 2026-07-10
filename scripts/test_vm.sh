#!/bin/bash
set -euo pipefail

# =================================================================
# eaSway - Lanzador de VM de Pruebas con Snapshot
# Crea un overlay descartable sobre la imagen base, inyecta
# cloud-init con la instalación de eaSway, y abre SPICE.
# Al cerrar la VM, el overlay se elimina → estado limpio.
# =================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/../test-images"
BASE_IMAGE="$IMAGES_DIR/debian-12-base.qcow2"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# -----------------------------------------------------------------
# 1. Validar imagen base
# -----------------------------------------------------------------
if [ ! -f "$BASE_IMAGE" ]; then
    echo -e "${YELLOW}[!] Imagen base no encontrada. Ejecutando prepare_base.sh...${NC}"
    bash "$SCRIPT_DIR/prepare_base.sh"
fi

# -----------------------------------------------------------------
# 2. Configuración
# -----------------------------------------------------------------
VM_NAME="easway-test-$(date +%s)"
OVERLAY="$IMAGES_DIR/$VM_NAME.qcow2"
SEED_ISO="$IMAGES_DIR/$VM_NAME-seed.iso"
SPICE_PORT=5900
SSH_PORT=2222
RAM_MB=2048
VCPUS=2

# -----------------------------------------------------------------
# 3. Crear overlay snapshot (COW sobre base inmutable)
# -----------------------------------------------------------------
echo -e "${CYAN}>> Creando snapshot overlay...${NC}"
qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$OVERLAY"

# -----------------------------------------------------------------
# 4. Generar cloud-init seed para este test
# -----------------------------------------------------------------
echo -e "${CYAN}>> Generando cloud-init seed...${NC}"

SEED_DIR=$(mktemp -d)

cat > "$SEED_DIR/user-data" <<'CLOUDEOF'
#cloud-config
hostname: easway-vm
locale: en_US.UTF-8
timezone: UTC

users:
  - name: easway
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: "$6$jUxfxARtJHgDWKCY$cCI51AZwJVcAyDdhfFSZz8dX/2YSSIO8iGx9H3yN1sUW/saMQaNGYWc13sORLyPkFGIxMmjqaXa82plSBXRUP/"
    shell: /bin/bash

ssh_pwauth: true
package_update: true
packages:
  - git

runcmd:
  - su - easway -c "git clone https://github.com/dozelix/eaSway.git /home/easway/eaSway 2>/dev/null || (cd /home/easway/eaSway && git pull)"
  - cd /home/easway/eaSway && sudo bash install.sh 2>&1 | tee /home/easway/install.log
  - sleep 2
  - systemctl reboot
CLOUDEOF

cat > "$SEED_DIR/meta-data" <<EOF
instance-id: $VM_NAME
local-hostname: easway-vm
EOF

genisoimage -output "$SEED_ISO" -volid cidata -joliet -rock "$SEED_DIR/user-data" "$SEED_DIR/meta-data" 2>/dev/null
rm -rf "$SEED_DIR"

# -----------------------------------------------------------------
# 5. Lanzar VM
# -----------------------------------------------------------------
echo -e "${CYAN}>> Iniciando VM (SPICE puerto $SPICE_PORT, SSH puerto $SSH_PORT)...${NC}"
echo -e "${YELLOW}   La VM arrancará, instalará eaSway automáticamente y reiniciará.${NC}"
echo -e "${YELLOW}   Después del reinicio, Sway se mostrará con el tema completo.${NC}"
echo ""

QEMU_CMD=(
    qemu-system-x86_64
    -machine q35,accel=kvm
    -m "$RAM_MB"
    -smp "$VCPUS"
    -cpu host
    -drive file="$OVERLAY",if=virtio,aio=threads
    -drive file="$SEED_ISO",if=virtio,media=cdrom
    -nic user,hostfwd=tcp::"$SSH_PORT"-:22
    -spice port="$SPICE_PORT",disable-ticketing=on
    -vga qxl
    -device virtio-9p-pci,fsdev=easwayfs,mount_tag=easway
    -fsdev local,security_model=mapped,id=easwayfs,path="$REPO_ROOT"
    -daemonize
)

"${QEMU_CMD[@]}"

echo -e "${GREEN}[OK] VM lanzada${NC}"

# -----------------------------------------------------------------
# 6. Abrir SPICE client
# -----------------------------------------------------------------
echo -e "${CYAN}>> Conectando SPICE...${NC}"
if command -v spicy &>/dev/null; then
    (sleep 3 && spicy -h 127.0.0.1 -p "$SPICE_PORT" &>/dev/null) &
elif command -v virt-viewer &>/dev/null; then
    (sleep 3 && virt-viewer --connect spice://127.0.0.1:"$SPICE_PORT" &>/dev/null) &
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  VM de prueba eaSway corriendo                               ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  Usuario: easway / Contraseña: easway                         ║${NC}"
echo -e "${GREEN}║  SPICE:   spicy -h 127.0.0.1 -p $SPICE_PORT                  ║${NC}"
echo -e "${GREEN}║  SSH:     ssh easway@localhost -p $SSH_PORT                   ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  El repo local está montado en /mnt (9p/virtiofs)             ║${NC}"
echo -e "${GREEN}║  mount -t 9p -o trans=virtio easway /mnt                     ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  Para limpiar:                                               ║${NC}"
echo -e "${GREEN}║    pkill qemu-system-x86                                     ║${NC}"
echo -e "${GREEN}║    rm -f $OVERLAY $SEED_ISO                                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"

# -----------------------------------------------------------------
# 7. Esperar y limpiar
# -----------------------------------------------------------------
echo ""
echo -e "${YELLOW}Presiona Enter cuando termines de probar para limpiar la VM...${NC}"
read -r

echo -e "${YELLOW}>> Limpiando...${NC}"
pkill -f "qemu.*$VM_NAME" 2>/dev/null || true
rm -f "$OVERLAY" "$SEED_ISO"
echo -e "${GREEN}[OK] Overlay eliminado. Estado limpio.${NC}"
