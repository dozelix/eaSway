### eaSway

Un instalador integral de instalación y personalización para elevar la experiencia de **Sway WM** al siguiente nivel. **SwayCLI** nace con el objetivo de eliminar la fricción inicial al configurar un gestor de ventanas tipo tiling. Ofrecemos una **herramienta CLI potente**, una **interfaz gráfica intuitiva** y una **experiencia de escritorio pulida** desde el primer segundo.

nuestro tipo de usuario es el que tiene conocimientos basicos de terminal en base debian que quiera implementar tillig en wayland sin muchas complicaciones.


---

### Estado del Proyecto

**v0.0.5-alpha**  
**en desarrollo**


---

### Arquitectura del Proyecto

```text
eaSway/
├── install.sh           # Entry point único (sudo cache + orquestador)
├── scripts/
│   ├── orchestrator.sh  # Orquestador de instalación
│   ├── check_hardware.sh
│   ├── install_packages.sh
│   ├── setup_config.sh
│   ├── post_install.sh
│   ├── gpu_environment.sh
│   └── uninstall.sh
├── dotfiles/            # Plantillas de configuración (sway, waybar, rofi, foot, mako)
└── assets/              # Recursos visuales y logos
```

---

### Entorno de Pruebas con VM (Snapshots)

Para probar eaSway sin tocar tu máquina principal, incluimos un sistema de VM con snapshots descartables basado en **QEMU/KVM + SPICE + cloud-init**.

**Requisitos:** Kernel con KVM (vmx/svm), ~2GB RAM libre, ~10GB disco

**Preparación (una sola vez):**  
Descarga la imagen cloud de Debian 12 y la inicializa:
```bash
bash scripts/prepare_base.sh
```

**Lanzar prueba:**  
Crea un snapshot overlay, inyecta cloud-init que instala eaSway automáticamente, y abre SPICE:
```bash
bash scripts/test_vm.sh
```

**Cómo funciona:**
- `prepare_base.sh` descarga Debian 12 cloud image (~300MB), la redimensiona a 15GB y la inicializa con cloud-init (usuario `easway`/`easway`).
- `test_vm.sh` crea un **overlay COW** (copy-on-write) sobre la imagen base — el boot es instantáneo, la base nunca se modifica.
- El cloud-init clona eaSway desde GitHub y ejecuta `install.sh` automáticamente.
- Después del primer boot + instalación, la VM reinicia y muestra Sway con el tema completo vía SPICE.
- Al cerrar, el overlay se elimina → estado 100% limpio para la próxima prueba.

**Credenciales VM:**  
```
Usuario: easway
Contraseña: easway
SSH:     ssh easway@localhost -p 2222
SPICE:   spicy -h 127.0.0.1 -p 5900
```

**Carpeta compartida (9p/virtiofs):**  
El repositorio local de eaSway se monta dentro de la VM en `/mnt`:
```bash
mount -t 9p -o trans=virtio easway /mnt
```

---

### Roadmap

- [x] **Soporte dinámico para Debian 12 Bookworm y Debian 13 Trixie**
- [x] **Soporte dinamico para las ultimas 2 versiones Ubuntu LTS**
- [x] **Scripts de desinstalación con protección de backups**
- [ ] **Implementación de sway-gui alpha**
- [ ] **Soporte oficial para distribuciones basadas en Arch Linux**

---

### Contribuir

¡Las contribuciones son lo que hacen a la comunidad open source un lugar increíble!

1. Haz un **Fork** del proyecto.  
2. Crea tu rama de función.  
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. Haz **commit** de tus cambios.  
4. Abre un **Pull Request**.

---

**Desarrollado con ❤️ por dozelix**