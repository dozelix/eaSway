### Changelog eaSway

Todos los cambios notables en este proyecto serán documentados en este archivo. El formato se basa en [Keep a Changelog](https://keepachangelog.com/) y este proyecto adhiere a [Semantic Versioning](https://semver.org/).

---

#### [0.0.4-alpha] - 2026-05-16

**Refactorización del Orquestador (`src/cli/`)**
- **Renombrado:** `main.sh` reemplazado por `install.sh` (v0.0.4) como punto de entrada principal.
- **Nuevo wrapper `run_install.sh`:** gestiona el cacheo de credenciales `sudo` antes de delegar al instalador, evitando interrupciones por expiración de sesión.
- **Logging centralizado:** toda la salida de cada paso se vuelca en `install.log` en la raíz del repo; se registra timestamp, usuario y resultado (SUCCESS / FAILED) por paso.
- **Validación de prerequisitos:** nueva función `validate_prerequisites()` verifica la disponibilidad de `bash` y `sudo` antes de iniciar cualquier operación.
- **Validación de scripts:** nueva función `validate_scripts()` confirma que los cinco módulos (`check_hardware.sh`, `install_packages.sh`, `setup_config.sh`, `post_install.sh`, `gpu_environment.sh`) existen en disco antes de la ejecución.
- **Propagación de variables de entorno:** `check_hardware.sh` ahora se ejecuta con `source` (`run_step_source`) para que `GPU_VENDOR`, `DEVICE_TYPE` e `IN_VM` sean visibles en los pasos posteriores sin subshells intermedios.
- **`set -euo pipefail`** añadido al orquestador para abortar ante cualquier error silencioso.
- **BUG#3 fix:** añadido color `BLUE` faltante y corregida la línea de resumen que usaba `${NC}` en lugar de `${BLUE}`.

---

**Módulo de Detección de Hardware (`scripts/check_hardware.sh`) — v0.0.4-alpha**
- **T05 FIX — Falsos positivos de virtualización con iGPU:** la detección de entorno virtual ahora prioriza la lectura de `/sys/class/dmi/id/board_vendor` (DMI) sobre `systemd-detect-virt`, evitando que drivers genéricos de GPU integrada sean confundidos con capas de virtualización.
- **T06 FIX — Validación de GPU real mediante módulos del kernel:** nueva función `is_real_gpu()` comprueba la presencia de módulos activos (`i915`, `amdgpu`, `nouveau`, `nvidia`) en `lsmod` antes de clasificar el fabricante; las GPUs virtuales o sin driver quedan marcadas como "Desconocido".
- **Exportación de variables por defecto en VM:** cuando se detecta virtualización, el script ahora exporta `GPU_VENDOR="Desconocido"` y `DEVICE_TYPE="desktop"` antes de salir, en lugar de dejar las variables vacías.
- **VM ya no aborta la instalación:** el módulo advierte y exporta configuración segura por defecto, permitiendo que el flujo continúe.
- **BUG#5 fix:** verificación de dependencias mínimas (`REQUIRED_CMDS`) reubicada para ejecutarse también en la ruta de VM (estaba después del `exit 0` temprano).
- **Nueva función `classify_gpu()`:** extrae la lógica de clasificación por fabricante en una función reutilizable.
- **Resumen final estructurado:** el módulo imprime siempre `Tipo de dispositivo`, `Fabricante de GPU` y `Entorno VM` antes de terminar.
- **`set -euo pipefail`** añadido.
- **Compatibilidad con `source` y ejecución directa:** manejo explícito de `BASH_SOURCE[0]` para devolver `return 0` o `exit 0` según el contexto de llamada.

---

**Módulo de Instalación (`scripts/install_packages.sh`)**
- Variables `OS_ID` y `OS_VER` ahora se asignan con comillas para prevenir expansión insegura (fix ShellCheck T02).
- `mapfile` reemplaza `read -r -a` para la división de la cadena de dependencias extra, mejorando el manejo de espacios.
- Función `get_extra_deps()` migrada a `printf` en lugar de `echo` para múltiples líneas.
- Fallbacks añadidos en el cálculo de tiempo de `stat` y en `date`.

---

**Módulo de Post-instalación (`scripts/post_install.sh`) — v0.0.4**
- **Eliminado `read -n 1` bloqueante** que impedía la ejecución no interactiva del instalador.
- **Instalación del wallpaper:** nueva lógica que copia el asset al directorio `~/wallpapers/` con prioridad `.webp` → `.png` → `.svg` (fallback).
- **BUG#7 fix:** añadido fallback a `easway_wallpaper_geometric.svg` para evitar que `swaybg` arranque con ruta nula cuando aún no existen los assets `.webp`/`.png`.
- **Fallback de usuario mejorado:** si `SUDO_USER` y `USER` no están disponibles, se busca el usuario por UID 1000 mediante `getent passwd`.
- **Grupo `seat` añadido** a `usermod -aG` para compatibilidad con `seatd` en Wayland.
- **Activación de `seatd`** vía `systemctl enable --now` cuando `systemd` está disponible.
- Creación de directorios `~/wallpapers/` y `~/capturas/` movida a este módulo.
- **`set -euo pipefail`** añadido.
- `readlink -f` reemplazado por `cd` + `pwd` para mayor compatibilidad POSIX.

---

**Configuración de Sway (`dotfiles/sway/config`) — v0.0.4-alpha**
- **BUG#6 fix:** extensión del wallpaper corregida de `.png` a `.webp` en la llamada a `swaybg`, para coincidir con el asset que instala `post_install.sh`.
- **Nuevos atajos de teclado:**
  - `$mod+b` → lanza Firefox.
  - `$mod+Shift+f` → lanza Thunar (gestor de archivos).
  - `$mod+Shift+d` → cierra Rofi si está abierto (`pkill rofi`).
- `exec swaybg -m fill -i ~/wallpapers/easway_wallpaper.webp` añadido al autostart.

---

**Terminal: migración de Kitty a Foot**
- `dotfiles/kitty/kitty.conf` eliminado del repositorio.
- Nueva configuración `dotfiles/foot/foot.ini` con la paleta neobrutalista del proyecto (fondo negro, cursor verde, fuente Noto Sans Mono Bold 11).
- Terminal por defecto (`$term`) cambiada a `foot` en `dotfiles/sway/config`.
- `foot` añadido a los paquetes críticos en `install_packages.sh`.

---

**Infraestructura de Testing (`test_vm_local.sh`)**
- `test_eaSway.sh` (Docker) reemplazado por `test_vm_local.sh`, que simula un entorno VM localmente sin necesitar Docker ni una VM real.
- Crea una estructura de sistema de archivos falsa (`$TEST_ENV_DIR`) con `systemd-detect-virt`, `lspci`, `sudo` y `os-release` mockeados.
- `check_hardware.sh` se ejecuta con `source` dentro del test para propagar `GPU_VENDOR`, `DEVICE_TYPE` e `IN_VM` a los pasos siguientes (**BUG#1 fix**).
- **BUG#5 fix:** greps de validación final actualizados para coincidir con el output real de `check_hardware.sh` (`"Entorno virtualizado detectado"`, `"Fabricante de GPU: Desconocido"`, `"Tipo de dispositivo: desktop"`).
- Trap de limpieza (`rm -rf "$TEST_ENV_DIR"`) en `EXIT`, `INT` y `TERM`.
- Archivo de log generado en `test_vm_local.log` y mostrado al final de la ejecución.
- `set -euo pipefail` añadido.
- Correcciones de ShellCheck (SC2155, SC2181).

---

**Assets**
- Añadidos `assets/wallpapers/easway_wallpaper.png` y `assets/wallpapers/easway_wallpaper.webp` al repositorio.

---

**Documentación**
- `docs/AUDIT_REPORT.md` nuevo: reporte de auditoría de scripts Bash con 5 bugs críticos, 3 warnings y 2 ítems de refactorización identificados y documentados.
- `docs/INSTALL_IMPROVEMENTS.md` nuevo: detalle de todas las correcciones de ShellCheck aplicadas en esta release y mejoras de automatización.
- `docs/index.md` actualizado con nueva estructura de ejemplos.
- `.editorconfig` añadido para normalizar indentación y fin de línea en el repo.
- `.vscode/extensions.json` y `.vscode/settings.json` añadidos para consistencia de entorno en VS Code.
- `Dockerfile` y `.dockerignore` eliminados de la rama `develop` (reemplazados por el entorno de test local).
- `.github/workflows/Dockerfile.yml` eliminado.

---

#### [0.0.3-alpha] - 2026-05-10

**Infraestructura de Testeo y CI/CD**
- **Sincronización de Usuario (ID #01):** Implementación de `ARG USER` en `Dockerfile.test` para replicar el UID/GID del host y evitar conflictos de permisos.
- **Orquestador de Pruebas:** Creación de `test_eaSway.sh` para automatizar el ciclo de construcción y ejecución del sandbox.
- **Hardware-Passthrough:** Habilitado el acceso a `/dev/dri` y `/dev/input` en el contenedor para validación de drivers.

**Módulo de Instalación (`main.sh`)**
- **Abstracción de OS (ID #02):** Detección dinámica de `/etc/os-release`.
- **Lógica Adaptativa:** Solución al fallo de dependencias en Debian 13 / Ubuntu 24.04 mediante el mapeo de `libegl1` vs `libegl1-mesa`.
- **Arrays Dinámicos:** Uso de `+=` para la inyección limpia de paquetes según la versión del sistema.

**Módulo de Desinstalación (`uninstall.sh`)**
- **Seguridad Crítica (SC2115):** Protección ante variables vacías con `${VAR:?}` para evitar borrados accidentales en `/`.
- **Gestión de Backups (SC2012):** Uso de `find` y `sort` para restaurar siempre la configuración más reciente.
- **Validación de Purga:** Verificación de longitud del array `PKGS` antes de ejecutar `apt`.

---

#### [0.0.2-alpha] - 2026-05-08

- **Robustez:** Implementada detección de `/.dockerenv` para omitir pasos de `systemd` incompatibles.
- **Hardware:** Exportación de `GPU_VENDOR` para visibilidad global en los scripts.
- **Sway Config:** Estabilización de `$XDG_RUNTIME_DIR` al inicio.

---

#### [0.0.1-alpha] - 2026-05-06

- Versión inicial del orquestador y estructura modular.

---

### Notas adicionales
- El changelog sigue el esquema **Unreleased / Added / Changed / Fixed / Removed** cuando aplique.
- Para contribuciones relacionadas con cambios en CI/CD o scripts críticos, favor de abrir PRs con referencias a los **IDs** de detección o seguridad cuando existan (por ejemplo, `ID #01`, `ID #02`).

---

**Desarrollado con ❤️ por dozelix**