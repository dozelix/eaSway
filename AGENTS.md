# AGENTS.md — eaSway

## Qué es
Instalador integral de Sway WM para Debian/Ubuntu. CLI + GUI. v0.0.5-alpha.

## Stack
- Bash scripts
- GTK4/Libadwaita (GUI planeada)
- QEMU/KVM + SPICE + cloud-init (VM testing)

## Comandos
```bash
bash install.sh                     # Instalación completa (sudo)
bash scripts/prepare_base.sh        # Descargar e inicializar VM base
bash scripts/test_vm.sh             # Lanzar VM de prueba con snapshot
ssh easway@localhost -p 2222        # SSH a la VM
spicy -h 127.0.0.1 -p 5900         # SPICE a la VM
```

## Estructura
- `install.sh` — entry point único
- `scripts/` — orquestador, check_hardware, packages, config, post_install, uninstall
- `dotfiles/` — plantillas (sway, waybar, rofi, foot, mako)
- `assets/` — recursos visuales

## Entorno de pruebas VM
- Snapshot COW (copy-on-write) sobre Debian 12 cloud image
- Cloud-init clona eaSway y ejecuta `install.sh` automáticamente
- Carpeta compartida en `/mnt` via 9p/virtiofs
- VM descartable: el overlay se elimina al cerrar

## Convenciones
- **Branches**: `feature/*` → `develop` → `main`
- **Commits**: conventional commits en español
- Usuario VM: `easway` / `easway`
- Roadmap: soporte Arch Linux pendiente
