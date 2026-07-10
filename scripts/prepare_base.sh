#!/bin/bash
set -euo pipefail

# =================================================================
# eaSway - Preparación de Imagen Base Debian 12 para VM de Pruebas
# Descarga la imagen cloud de Debian 12, la redimensiona y la deja
# lista para usar con test_vm.sh
# =================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/../test-images"
BASE_IMAGE="$IMAGES_DIR/debian-12-base.qcow2"
CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
CLOUD_IMAGE="$IMAGES_DIR/debian-12-generic-amd64.qcow2"
DISK_SIZE="15G"

mkdir -p "$IMAGES_DIR"

echo -e "${CYAN}>> Preparando imagen base para VM de pruebas eaSway${NC}"

# -----------------------------------------------------------------
# 1. Instalar dependencias
# -----------------------------------------------------------------
DEPS_MISSING=0
for cmd in qemu-system-x86_64 genisoimage spicy; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${YELLOW}[!] Falta: $cmd${NC}"
        DEPS_MISSING=1
    fi
done

if [ "$DEPS_MISSING" -eq 1 ]; then
    echo -e "${YELLOW}>> Instalando dependencias...${NC}"
    sudo pacman -S --needed --noconfirm qemu-system-x86 virt-viewer cdrtools
fi

# -----------------------------------------------------------------
# 2. Descargar cloud image si no existe
# -----------------------------------------------------------------
if [ -f "$CLOUD_IMAGE" ]; then
    echo -e "${GREEN}[OK] Imagen cloud ya descargada${NC}"
else
    echo -e "${YELLOW}>> Descargando Debian 12 cloud image (∼300MB)...${NC}"
    wget -O "$CLOUD_IMAGE" "$CLOUD_IMAGE_URL"
    echo -e "${GREEN}[OK] Descarga completada${NC}"
fi

# -----------------------------------------------------------------
# 3. Crear base image redimensionada
# -----------------------------------------------------------------
if [ -f "$BASE_IMAGE" ]; then
    echo -e "${GREEN}[OK] Imagen base ya preparada en $BASE_IMAGE${NC}"
else
    echo -e "${YELLOW}>> Creando imagen base (copia + resize a $DISK_SIZE)...${NC}"
    cp "$CLOUD_IMAGE" "$BASE_IMAGE"
    qemu-img resize "$BASE_IMAGE" "$DISK_SIZE"
    echo -e "${GREEN}[OK] Imagen base creada: $BASE_IMAGE${NC}"
fi

# -----------------------------------------------------------------
# 4. Crear seed ISO de inicialización (cloud-init primer arranque)
# -----------------------------------------------------------------
SEED_DIR="$IMAGES_DIR/seed-init"
mkdir -p "$SEED_DIR"

PASS_HASH=$(openssl passwd -6 easway 2>/dev/null || echo '$6$jUxfxARtJHgDWKCY$cCI51AZwJVcAyDdhfFSZz8dX/2YSSIO8iGx9H3yN1sUW/saMQaNGYWc13sORLyPkFGIxMmjqaXa82plSBXRUP/')

cat > "$SEED_DIR/user-data" <<EOF
#cloud-config
hostname: easway-vm
locale: en_US.UTF-8
timezone: UTC

users:
  - name: easway
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: "$PASS_HASH"
    shell: /bin/bash
    homedir: /home/easway

ssh_pwauth: true
package_update: true
package_upgrade: false
packages:
  - git
  - sudo

write_files:
  - path: /etc/sudoers.d/easway
    content: "easway ALL=(ALL) NOPASSWD:ALL\n"
    permissions: "0440"

runcmd:
  - [ systemctl, daemon-reload ]
  - [ poweroff ]
EOF

cat > "$SEED_DIR/meta-data" <<EOF
instance-id: easway-vm-init
local-hostname: easway-vm
EOF

echo -e "${YELLOW}>> Creando seed ISO de inicialización...${NC}"
genisoimage -output "$IMAGES_DIR/seed-init.iso" -volid cidata -joliet -rock "$SEED_DIR/user-data" "$SEED_DIR/meta-data" 2>/dev/null
rm -rf "$SEED_DIR"

# -----------------------------------------------------------------
# 5. Inicializar la imagen base (primer boot con cloud-init)
# -----------------------------------------------------------------
echo -e "${YELLOW}>> Inicializando imagen base (primer boot con cloud-init)...${NC}"

echo -e "${YELLOW}   (Esto toma ~2-3 minutos, espera a que termine...)${NC}"
timeout 240 qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -m 768 \
    -smp 2 \
    -nographic \
    -drive file="$BASE_IMAGE",if=virtio,aio=threads \
    -drive file="$IMAGES_DIR/seed-init.iso",if=virtio,media=cdrom \
    -nic user \
    -no-reboot \
    -cpu host || true
echo -e "${GREEN}[OK] Primer boot completado${NC}"

rm -f "$IMAGES_DIR/seed-init.iso"

echo -e "${GREEN}"
echo -e "╔══════════════════════════════════════════════════════╗"
echo -e "║  Imagen base lista:                                  ║"
echo -e "║    $BASE_IMAGE"
echo -e "║                                                      ║"
echo -e "║  Usa 'bash test_vm.sh' para lanzar una prueba        ║"
echo -e "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
