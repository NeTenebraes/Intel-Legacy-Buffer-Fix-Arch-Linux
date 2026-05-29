# Intel Legacy | Artifact Buffer Fix X11 (Arch Linux)

Este es un script de automatización diseñado para corregir los fallos de renderizado (patrones de líneas verticales o corrupción de pantalla) en GPUs integradas de legado Intel en sistemas Archlinux.
![Antes](https://github.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/blob/main/images/Antes.webp?raw=true)
> Testeado en Intel Gen 6 / Sandy Bridge / HD 2000 bajo el servidor gráfico X11 en el entorno `bspwm`.

## El Problema (Mesa 26.x y el driver Crocus)
Las versiones modernas de la pila gráfica **Mesa** sustituyeron los controladores clásicos por el driver genérico **Crocus**. 

Los cambios en este controlador introdujeron regresiones graves en la asignación de memoria intermedia (*ring buffer*) de los chipsets Sandy Bridge de Intel. Esto genera artefactos masivos de color en toda la pantalla (lineas verticales/horizontales).

También hay que tener en cuenta que el backend por defecto de **DRI3** sufre de desbordamientos de búfer de texturas al realizar operaciones rápidas de escalado o redibujado dinámico luego de dichos cambios.


## La Solución
Este script automatiza la reconfiguración del sistema aplicando varias capas de mitigación:
1. **Instalación de Drivers DDX Dedicados:** Asegura la presencia de `xf86-video-intel`, un componente que las instalaciones limpias de Arch suelen omitir y cuya ausencia rompe el arranque de Xorg.
2. **Reemplazo del Motor Gráfico:** Remueve de forma segura la pila de Mesa moderna y la sustituye por `mesa-amber`, el fork oficial que conserva intacto el código de hardware heredado estable (`i965`).
3. **Degradación Controlada a UXA y DRI2:** Fuerza al servidor X11 a gestionar los píxeles mediante un pipeline síncrono y predecible, eliminando por los desbordamientos de búfer.
4. **Parche de Renderizado para SDDM (Opcional):** Aísla el gestor de inicio de sesión obligándolo a renderizar por software (CPU) para evitar congelamientos en el login antes de cargar tu entorno gráfico.
5. Crea un respaldo de tu configuración antigüa de xorg.

## Uso
Ejecuta el siguiente comando en tu terminal para aplicar el parche automáticamente:

### No SDDM
```bash
curl -sL https://raw.githubusercontent.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/main/intel-legacy-fix.sh | sudo bash
```
### SDDM Fix
```bash
bash <(curl -sL https://raw.githubusercontent.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/main/intel-legacy-fix.sh) --sddm
```

## Detalles Técnicos: ¿Que hace este script?

### 1. Reconfiguración del Servidor Gráfico X11
El script genera el archivo `/etc/X11/xorg.conf.d/20-intel.conf` e inyecta directivas estrictas de hardware:
* `Option "AccelMethod" "uxa"`: Sustituye el método SNA por **UXA** (*Unified X Acceleration*). No intenta adivinar texturas dinámicas en la memoria intermedia, garantizando un redibujado de fuentes e interfaces limpio. Es un método de aceleración más antiguo pero infinitamente más predecible con los píxeles. No intenta adivinar texturas en la memoria intermedia.

* `Option "DRI" "2"`: Fuerza el uso de *Direct Rendering Infrastructure 2*. DRI2 gestiona la memoria de video de forma estrictamente síncrona, impidiendo que las aplicaciones manden comandos gráficos más rápido de lo que la GPU integrada puede procesar. DRI2 gestiona la memoria de video de forma síncrona y estricta, impidiendo que las aplicaciones manden comandos gráficos más rápido de lo que este hardware puede procesar.

* `Option "TearFree" "true"`: Habilita el doble búfer nativo por hardware para erradicar el desgarro de pantalla (*tearing*) al hacer scroll.

### 2. Aislamiento de Variables de Entorno (`environment.d`)
Librerías modernas basadas en Qt o entornos Electron (como VS Code o Discord) suelen saltarse las reglas globales de Xorg. El script mitiga esto creando `/etc/environment.d/99-mesa-legacy.conf`:
* `LIBGL_DRI3_DISABLE=1`: Desactiva el paso de búferes vía DRI3 a nivel de librerías cliente OpenGL, forzando el canal seguro DRI2.
* `MESA_LOADER_DRIVER_OVERRIDE=i965`: Le ordena de forma explícita al cargador de Mesa ignorar por completo el controlador genérico moderno (`crocus`) y levantar exclusivamente el driver clásico de Intel.

### 3. Gestión de Conflictos en Paquetes
La función interna del script detecta de forma automática si el paquete `mesa` estándar está presente, aplicando un reemplazo agresivo controlado (`pacman -Rdd`) para evitar que el gestor de paquetes de Arch aborte por conflictos de archivos gráficos compartidos, inyectando inmediatamente la pila Amber estab
le.

- **Descarga e instala mesa-amber y lib32-mesa-amber**: Este es un repositorio oficial y mantenido de Mesa que conserva intacto el código fuente clásico y nativo para hardware legacy de Intel.

- **Reemplazo de la pila**: Al instalarlo, reemplaza la pila de Mesa moderna, asegurando que tu GPU vuelva a hablar en su "idioma nativo" a nivel de kernel.

### 4. Mitigación de Fallos en el Gestor de Accesos (SDDM Greeter Parche)
La pantalla de inicio de sesión de SDDM utiliza por defecto un motor de renderizado llamado **Qt Quick / QML**, el cual exige llamadas OpenGL modernas y perfiles de sombreadores que causan parpadeos (*flashes*), congelamientos parciales o retrasos en el arranque de chipsets Sandy Bridge antes de cargar el entorno de usuario.

Al invocar el script con la bandera `--sddm`, se genera el archivo de anulación `/etc/sddm.conf.d/10-mesa-legacy.conf` aplicando un aislamiento estricto al entorno del greeter:
* `QT_QUICK_BACKEND=software` y `QT_OPENGL=software`: Ordenan al gestor gráfico de Qt ignorar la GPU en durante la pantalla de login, forzando a la CPU a dibujar la interfaz de manera plana y segura.
* `LIBGL_ALWAYS_SOFTWARE=1`: Funciona como un seguro adicional de bajo nivel que bloquea cualquier intento de inicialización 3D acelerada por parte de la librería GL antes de que se inicie la sesión real de Xorg.
* `MESA_GL_VERSION_OVERRIDE=3.0` y `MESA_GLSL_VERSION_OVERRIDE=130`: Engañan al subsistema gráfico de SDDM emulando un perfil plano heredado compatible, previniendo los cuelgues del proceso de autenticación.

> **Nota:** Este parche afecta única y exclusivamente a la pantalla de login de SDDM. Una vez introducidas las credenciales de usuario, las variables se destruyen y el control pasa al servidor X11 normal, donde tu entorno aprovechará la aceleración 2D/3D real por hardware optimizada mediante UXA y Mesa Amber.

## En resumen

![Despues](https://github.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/blob/main/images/Despues.webp?raw=true)

Al ejecutar el oneliner, resuelves el desborde matemático de la VRAM. El sistema operativo deja de exigirle a tu GPU Intel clásica funciones de renderizado modernas y la estabiliza en un modo óptimo y robusto de operación, obteniendo un entorno gráfico ligero e inmune a las rayas de corrupción de pantalla sin importar el zoom o los glifos que uses.

## Disclaimer

* **Entorno de Pruebas Restringido:** Este script ha sido desarrollado y probado **única y exclusivamente bajo la distribución Arch Linux** en un entorno de hardware específico. No se garantiza su comportamiento ni se ha verificado su compatibilidad en otras distribuciones de tipo Rolling Release.
* **Uso Bajo Propio Riesgo:** El script realiza modificaciones profundas en archivos de configuración del sistema crítico (`Xorg`, variables de entorno globales y sustitución de controladores de video a nivel de empaquetado). **No me hago responsable por ningún tipo de daño**, pérdida de datos, fallos en el arranque del entorno gráfico o inestabilidad del sistema operativo derivados de su ejecución.
* **Recomendación Imperativa:** Se recomienda encarecidamente realizar copias de seguridad de tus archivos de configuración esenciales antes de proceder. Aunque el script genera respaldos automáticos de los archivos que interviene (como `.bak` con marca de tiempo), la precaución previa corre por cuenta del usuario.
