# Intel Legacy | Artifact Buffer Fix X11 (Arch Linux)

Este es un script de automatización diseñado para corregir los fallos de renderizado (patrones de líneas verticales o corrupción de pantalla) en GPUs integradas de legado Intel en sistemas Archlinux.

> En español: Arregla las lineas de colores que aparecen en la terminal y algunas aplicaciones, afectando directamente a CPUs Intel de 2da generación en sistemas operativos ArchLinux.

![Antes](https://github.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/blob/main/images/Antes.webp?raw=true)


> [!WARNING]
> Este script ha pasado por múltiples pruebas en mi equipo intel i3 de 2da generación.
> - Actualmente se están haciendo pruebas para no tener que usar configuración obsoleta.
> - Esta configuración es exclusiva para hardware Intel Legacy con Mesa Amber.
> - No se ha probado su comportamiento en Wayland.
> - Testeado en Intel Gen 6 / Sandy Bridge / HD 2000 bajo el servidor gráfico X11 en el entorno `bspwm`.


## El Problema (Mesa 26.x y el driver Crocus)
Las versiones modernas de la pila gráfica **Mesa** sustituyeron los controladores clásicos por el driver **Crocus**. 

Los cambios en este controlador introdujeron regresiones graves en la asignación de memoria intermedia (*ring buffer*) de los chipsets Sandy Bridge de Intel. Esto genera artefactos masivos (lineas verticales/horizontales) en algunas secciones de la pantalla.

## La Solución
Este script automatiza la reconfiguración del sistema aplicando varias capas de mitigación:
1. ~~**Instalación de Drivers DDX Dedicados:** Asegura la presencia de `xf86-video-intel`, un componente que las instalaciones limpias de Arch suelen omitir y cuya ausencia rompe el arranque de Xorg con la directiva "intel".~~
2. **Reemplazo del Motor Gráfico:** Remueve de forma segura la pila de Mesa moderna y la sustituye por `mesa-amber`, el fork oficial que conserva intacto el código de hardware heredado estable (`i965`).
3. ~~**Inyección de Aceleración Nativa (SNA)**: En lugar de forzar el método UXA (más lento), el script habilita SNA (SandyBridge New Acceleration) en conjunto con el protocolo DRI3 y la directiva TearFree. Al estar respaldado por Mesa Amber, este entorno elimina los desbordamientos de memoria intermedia, desbloqueando la máxima fluidez y velocidad del chip sin riesgo de corrupción.~~
4. **Parche de Renderizado para SDDM (Opcional):** Aísla el gestor de inicio de sesión obligándolo a renderizar por software (CPU) para evitar congelamientos en el login antes de cargar tu entorno gráfico.
5. Crea un respaldo de tu configuración antigüa de xorg.

> En si, lo mas importante es volver a utilizar  `mesa-amber`. Las demás configuraciones son para indicar de forma explícita los parámetros a usar.

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

## Detalles Técnicos: ¿Qué hace este script?

### 1. Reconfiguración del Servidor Gráfico X11
El script genera el archivo `/etc/X11/xorg.conf.d/20-intel.conf` e inyecta directivas de hardware para optimizar el rendimiento en chipsets Sandy Bridge:
* ~~**`Option "AccelMethod" "sna"`**: Habilita la arquitectura *SandyBridge New Acceleration*. Al combinarse con la pila Mesa Amber, SNA balancea de forma inteligente la carga entre CPU y GPU, permitiendo una fluidez superior en animaciones y scroll de navegación sin riesgo de artefactos.~~
* **`Option "DRI" "3"`**: Habilita *Direct Rendering Infrastructure 3*. Al utilizarse sobre una base estable como Mesa Amber, este protocolo permite una comunicación de memoria más eficiente y de baja latencia entre las aplicaciones y la GPU, maximizando el rendimiento sin las inestabilidades previas.
* **`Option "TearFree" "true"`**: Activa el doble búfer nativo por hardware, eliminando por completo el desgarro de pantalla (*tearing*) durante el redibujado dinámico.

### 2. Gestión de Paquetes y Conflictos
Implementa una sustitución agresiva pero controlada de los controladores gráficos para evitar errores en el gestor de paquetes de Arch Linux:
* **Reemplazo con `pacman -Rdd`**: Detecta y remueve la pila de Mesa estándar sin romper dependencias críticas, inyectando inmediatamente `mesa-amber` y `lib32-mesa-amber`.
* **Restauración del código nativo**: Al instalar la rama Amber, se recupera el código fuente original diseñado para hardware legacy, permitiendo que la GPU vuelva a operar en su arquitectura estable a nivel de kernel.

### 3. Mitigación para el Gestor de Accesos (Parche opcional para SDDM)
Al usar la bandera `--sddm`, el script genera `/etc/sddm.conf.d/10-mesa-legacy.conf` para aislar el entorno del greeter (Qt Quick / QML) y evitar congelamientos en el login:
* **Renderizado por Software**: Fuerza a la CPU (`QT_QUICK_BACKEND=software` y `LIBGL_ALWAYS_SOFTWARE=1`) a dibujar la interfaz de inicio de sesión de manera plana, evitando llamadas OpenGL modernas que el hardware Sandy Bridge tiene problemas para procesar antes de iniciar la sesión.
* **Emulación de Perfiles**: Utiliza overrides de versión de GL y GLSL para engañar al subsistema gráfico de SDDM, previniendo cuelgues durante el proceso de autenticación.
> **Nota:** Estas restricciones de software se aplican exclusivamente a la pantalla de login. Una vez iniciada la sesión, el control total regresa al servidor X11 con aceleración real por hardware mediante SNA y Mesa Amber.

### 4. Aislamiento de Variables de Entorno (`environment.d`)
- ~~Crea el ~~ archivo `/etc/environment.d/99-mesa-legacy.conf` para asegurar que librerías modernas (Qt o entornos Electron como VS Code) respeten la configuración global del sistema~~
* ~~**`MESA_LOADER_DRIVER_OVERRIDE=i965`**: Ordena explícitamente al cargador de Mesa ignorar el controlador genérico moderno (`crocus`) y utilizar exclusivamente el driver clásico de Intel.~~
* ~~**`LIBGL_DRI3_DISABLE=0`**: Permite el uso de DRI3 a nivel de librerías cliente, aprovechando la mejora de rendimiento en el intercambio de búferes de video.~~

## En resumen

![Despues](https://github.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/blob/main/images/Despues.webp?raw=true)

Al ejecutar el oneliner, resuelves el desborde matemático de la VRAM. El sistema operativo deja de exigirle a tu GPU Intel clásica funciones de renderizado modernas y la estabiliza en un modo óptimo y robusto de operación, obteniendo un entorno gráfico ligero e inmune a las rayas de corrupción de pantalla sin importar el zoom o los glifos que uses.

## Disclaimer

* **Entorno de Pruebas Restringido:** Este script ha sido desarrollado y probado **única y exclusivamente bajo la distribución Arch Linux** en un entorno de hardware específico. No se garantiza su comportamiento ni se ha verificado su compatibilidad en otras distribuciones de tipo Rolling Release.
* **Uso Bajo Propio Riesgo:** El script realiza modificaciones profundas en archivos de configuración del sistema crítico (`Xorg`, variables de entorno globales y sustitución de controladores de video a nivel de empaquetado). **No me hago responsable por ningún tipo de daño**, pérdida de datos, fallos en el arranque del entorno gráfico o inestabilidad del sistema operativo derivados de su ejecución.
* **Recomendación Imperativa:** Se recomienda encarecidamente realizar copias de seguridad de tus archivos de configuración esenciales antes de proceder. Aunque el script genera respaldos automáticos de los archivos que interviene (como `.bak` con marca de tiempo), la precaución previa corre por cuenta del usuario.
