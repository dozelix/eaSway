## Documentación Técnica de eaSway

Bienvenido a la documentación centralizada del ecosistema **eaSway**. Este proyecto busca proporcionar una experiencia de **Sway WM** lista para usar, altamente técnica y modular.

---

### Guías Rápidas

#### 1 Filosofía del Proyecto
- **Modularidad:** Cada script (`install`, `setup`, `hardware`) debe funcionar de forma independiente.  
- **Seguridad:** Nunca borrar configuraciones del usuario sin crear un **backup** previo.  
- **Transparencia:** El usuario debe saber exactamente qué paquetes se están instalando.

#### 2 Estándares de Código
- **Validación:** Todos los scripts deben pasar la validación de **shellcheck**.  
- **Estructuras:** Uso obligatorio de **arrays** para listas de paquetes o archivos.  
- **Protección de variables:** Protección de variables críticas mediante expansiones de parámetros `:?`.

#### 3 Desarrollo y Pruebas
- **Entorno Docker:** Para contribuir al core lógico, utiliza el entorno **Docker** proporcionado.  
- **Compatibilidad:** Esto asegura que tus cambios no rompan la compatibilidad con instalaciones limpias de **Debian**.  
- **Próximo Hito:** **Sprint 2** — Detección de Hardware y Variables de Entorno de Video.

---

### Ejemplos y Fragmentos Útiles

**Estructura del repositorio**

```text
eaSway/
├── install.sh           # Entry point único
├── scripts/
│   ├── orchestrator.sh
│   ├── check_hardware.sh
│   ├── install_packages.sh
│   ├── setup_config.sh
│   ├── post_install.sh
│   ├── gpu_environment.sh
│   └── uninstall.sh
├── dotfiles/
└── assets/
```

**Comando para lanzar tests en sandbox**

```bash
chmod +x test_vm_local.sh
./test_vm_local.sh
```

**Detección de OS en bash**

```bash
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID="$ID"
  OS_VERSION="$VERSION_ID"
fi
```

**Protección de variables críticas en uninstall**

```bash
TARGET_DIR="${TARGET_DIR:?Se requiere TARGET_DIR para evitar borrados accidentales}"
```

**Inyección dinámica de paquetes**

```bash
PKGS=()
PKGS+=("sway" "wayland-protocols")
if [ "$OS_ID" = "debian" ] && [ "$OS_VERSION" = "13" ]; then
  PKGS+=("libegl1-mesa")
else
  PKGS+=("libegl1")
fi
```

---

### Buenas Prácticas para Contribuciones

- **Fork y ramas:** Haz un fork y crea una rama por feature.  
- **Commits claros:** Mensajes de commit descriptivos y atómicos.  
- **PRs con contexto:** Incluye referencias a IDs de detección o seguridad cuando aplique.  
- **Pruebas:** Asegura que tus cambios pasen `test_vm_local.sh` en el sandbox antes de abrir el PR.

---

### Entorno de Desarrollo Recomendado
- **VS Code:** instala la extensión [`timonwong.shellcheck`](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck) para validación de scripts en tiempo real.
- El archivo `.editorconfig` ya normaliza el fin de línea a LF para todos los `.sh`.
(si esto no funciona, editarlo en el perfil del workspace dentro de vscode)

---

### Contacto y Créditos

**Desarrollado con ❤️ por dozelix**