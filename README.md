# Intel Legacy Buffer Fix (Arch Linux)

Un script de automatización diseñado para corregir los fallos de renderizado (patrones de líneas verticales o corrupción de pantalla) en GPUs integradas Intel de legado (Testeado en Gen 2) bajo el servidor gráfico X11 y entornos ligeros (`bspwm`, `i3wm`).

![Antes](https://github.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/blob/main/images/Antes.webp?raw=true)

## El Problema
Las versiones modernas de la pila gráfica **Mesa** y el backend por defecto de **DRI3** sufren de desbordamientos de búfer de texturas al realizar operaciones rápidas de escalado o redibujado dinámico (como el zoom en terminales GPU-accelerated o renderizado de glifos complejos). Esto genera artefactos masivos de color en toda la pantalla (lineas verticales/horizontales).

## La Solución
Este script automatiza la reconfiguración del sistema aplicando tres capas de mitigación:
1. Instala y reemplaza de forma automática los paquetes necesarios. 
2. Fuerza el uso de la arquitectura de aceleración **UXA** y degrada el pipeline gráfico a **DRI2** seguro.
3. Configura variables de entorno críticas en `environment.d` para bloquear llamadas DRI3 en aplicaciones Qt/Electron.
4. Reemplaza la pila de drivers principal de Mesa con los paquetes oficiales `mesa-amber` (los cuales retienen el código de hardware legacy estable).
5. Crea un respaldo de tu configuración antigüa de xorg.

## Uso
Ejecuta el siguiente comando en tu terminal para aplicar el parche automáticamente:

```bash
curl -sL https://raw.githubusercontent.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/main/intel-legacy-fix.sh | sudo bash
```

## ¿Qué hace este script?
### 1. Degradación Controlada del Pipeline Gráfico (Xorg)

Por defecto, los entornos Linux modernos intentan usar DRI3 (Direct Rendering Infrastructure 3) y el método de aceleración SNA. En hardware antiguo, **esto es una bomba de tiempo**. Cuando cambias el tamaño de una ventana, haces zoom en terminales renderizadas por GPU o cargas iconos pesados, la GPU no procesa las texturas a tiempo, el búfer de video se desalinea y se pinta una "persiana" de rayas en tu pantalla.

El script busca solucionar esto creando el archivo `/etc/X11/xorg.conf.d/20-intel.conf` e inyectando la siguiente configuración:  

- **Option "AccelMethod" "uxa"**: Apaga SNA y activa UXA (Unified X Acceleration).  
> Es un método de aceleración más antiguo pero infinitamente más predecible con los píxeles. No intenta adivinar texturas en la memoria intermedia.

- **Option "DRI" "2"**: Fuerza al servidor X11 a usar la versión 2 de la infraestructura de renderizado directo.  
> DRI2 gestiona la memoria de video de forma síncrona y estricta, impidiendo que las aplicaciones manden comandos gráficos más rápido de lo que tu hardware puede procesar.

- **Option "TearFree" "true"**: Crea un doble búfer por hardware para evitar que la pantalla se "rompa" al hacer scroll.  

### 2. Bloqueo de Llamadas DRI3 en Aplicaciones Modernas (Environment)

Muchas aplicaciones modernas (especialmente las basadas en Qt como emuladores/herramientas de diseño, o en Electron como VS Code, Discord y Spotify) ignoran la configuración global de Xorg e intentan abrir canales directos de renderizado avanzado usando llamadas a librerías de bajo nivel.

Para evitar esto, el script genera el archivo `/etc/environment.d/99-mesa-legacy.conf` estableciendo las siguientes variables de entorno:  

- **LIBGL_DRI3_DISABLE=1**: Le pone un candado a la librería cliente de OpenGL.
> Cualquier programa que se ejecute en tu sesión bspwm se ve obligado a renderizar usando el canal seguro DRI2 que configuramos en el paso anterior.  

- **MESA_LOADER_DRIVER_OVERRIDE=i965**: Le dice al cargador de Mesa: "No uses drivers genéricos modernos (como Crocus) y carga explícitamente el driver clásico i965".

### 3. Reemplazo del Motor Gráfico (Mesa Amber)

Esta es la parte más crítica del script. Las versiones actuales de Mesa intentan emular tu GPU de legado con drivers modernos, lo cual genera fallos matemáticos fatales en la memoria de video.

El script detecta y automatiza la transición mediante pacman:

- **Descarga e instala mesa-amber y lib32-mesa-amber**: Este es un repositorio oficial y mantenido de Mesa que conserva intacto el código fuente clásico y nativo para hardware legacy de Intel.

- **Reemplazo de la pila**: Al instalarlo, reemplaza la pila de Mesa moderna, asegurando que tu GPU vuelva a hablar en su "idioma nativo" a nivel de kernel.

### 4. Fix opcional para SDDM

Algunas instalaciones muestran un flash al cargar el greeter. Para mitigarlo, el script puede fijar variables de entorno del greeter de SDDM y forzar renderizado software solo en el login.

Activación:

```bash
sudo bash intel-legacy-fix.sh --sddm
```

## En resumen

![Despues](https://github.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/blob/main/images/Despues.webp?raw=true)

Al ejecutar el oneliner, resuelves el desborde matemático de la VRAM. El sistema operativo deja de exigirle a tu GPU Intel clásica funciones de renderizado modernas y la estabiliza en un modo óptimo y robusto de operación, obteniendo un entorno gráfico ligero e inmune a las rayas de corrupción de pantalla sin importar el zoom o los glifos que uses.
