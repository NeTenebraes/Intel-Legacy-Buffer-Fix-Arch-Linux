# Intel Legacy Buffer Fix (Arch Linux)

Un script de automatización diseñado para corregir los fallos de renderizado (patrones de líneas verticales o corrupción de pantalla) en GPUs integradas de Intel integradas de legado (Testeado en Gen 2) bajo el servidor gráfico X11 y entornos ligeros (`bspwm`, `i3wm`).

## El Problema
Las versiones modernas de la pila gráfica **Mesa** (versiones posteriores a 2022) y el backend por defecto de **DRI3** sufren de desbordamientos de búfer de texturas al realizar operaciones rápidas de escalado o redibujado dinámico (como el zoom en terminales GPU-accelerated o renderizado de glifos complejos). Esto genera artefactos masivos de color en toda la pantalla.

## La Solución Estructural
Este script automatiza la reconfiguración del sistema aplicando tres capas de mitigación:
1. Fuerza el uso de la arquitectura de aceleración **UXA** y degrada el pipeline gráfico a **DRI2** seguro.
2. Configura variables de entorno críticas en `environment.d` para bloquear llamadas DRI3 en aplicaciones Qt/Electron.
3. Reemplaza la pila de drivers principal de Mesa con los paquetes oficiales **Mesa Amber** (`mesa-amber`), los cuales retienen el código de hardware legacy estable.

## Us
```bash
curl -sL https://raw.githubusercontent.com/NeTenebraes/Intel-Legacy-Buffer-Fix-Arch-Linux/main/intel-legacy-fix.sh | sudo bash
```
