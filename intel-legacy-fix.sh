#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: intel-legacy-fix.sh
# DESCRIPCIÓN: Corrige la corrupción del búfer de video (patrón de líneas verticales)
#              en arquitecturas Intel Legacy mediante el downgrade controlado a DRI2,
#              UXA y el backend clásico de Mesa (Mesa Amber).
# AUTOR: netenebrae
# ==============================================================================

set -euo pipefail

# Verificación de privilegios de ejecución (Requerido para modificar configuraciones del sistema)
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

# Definición de rutas globales de configuración
XORG_CONF_DIR="/etc/X11/xorg.conf.d"
XORG_CONF_FILE="$XORG_CONF_DIR/20-intel.conf"
ENV_DIR="/etc/environment.d"
ENV_FILE="$ENV_DIR/99-mesa-legacy.conf"

timestamp=$(date +%Y%m%d-%H%M%S)

# ------------------------------------------------------------------------------
# GESTIÓN DE DEPENDENCIAS: MESA AMBER (DRIVERS DE GRADUADOS / LEGACY)
# ------------------------------------------------------------------------------
# El driver principal de Mesa removió el soporte nativo de hardware clásico.
# Es mandatorio instalar el fork oficial 'mesa-amber' para recuperar el soporte 3D real.
# ------------------------------------------------------------------------------
if ! pacman -Q mesa-amber >/dev/null 2>&1; then
  pacman -S --noconfirm mesa-amber
fi

if ! pacman -Q lib32-mesa-amber >/dev/null 2>&1; then
  pacman -S --noconfirm lib32-mesa-amber
fi

# Asegurar la existencia de los directorios del sistema de archivos
mkdir -p "$XORG_CONF_DIR" "$ENV_DIR"

# Mecanismo de respaldo (Backup) preventivo de la configuración previa de Xorg
if [[ -f "$XORG_CONF_FILE" ]]; then
  cp "$XORG_CONF_FILE" "${XORG_CONF_FILE}.bak.${timestamp}"
fi

# ------------------------------------------------------------------------------
# CONFIGURACIÓN DE XORG (SERVIDOR GRÁFICO X11)
# ------------------------------------------------------------------------------
# - AccelMethod "uxa": Reemplaza SNA por la arquitectura de aceleración clásica (Unified
#   X Acceleration). Previene desbordamientos de búfer en renderizado dinámico de fuentes.
# - TearFree "true": Habilita el control de sincronización vertical nativo por hardware.
# - DRI "2": Fuerza el uso de Direct Rendering Infrastructure 2, evitando las llamadas
#   asíncronas conflictivas de DRI3 en chipsets antiguos.
# ------------------------------------------------------------------------------
cat > "$XORG_CONF_FILE" <<'EOF'
Section "Device"
    Identifier "Intel Graphics"
    Driver "intel"
    Option "AccelMethod" "uxa"
    Option "TearFree" "true"
    Option "DRI" "2"
EndSection
EOF

# ------------------------------------------------------------------------------
# VARIABLES DE ENTORNO PARA MESA / DRI
# ------------------------------------------------------------------------------
# - MESA_LOADER_DRIVER_OVERRIDE=i965: Fuerza explícitamente el uso del driver clásico
#   de Intel dentro de la pila gráfica de Mesa, ignorando Crocus/Iris.
# - LIBGL_DRI3_DISABLE=1: Desactiva por completo el paso de búferes vía DRI3 a nivel de
#   librerías cliente OpenGL (esencial para aplicaciones basadas en Qt/Electron).
# ------------------------------------------------------------------------------
cat > "$ENV_FILE" <<'EOF'
MESA_LOADER_DRIVER_OVERRIDE=i965
LIBGL_DRI3_DISABLE=1
EOF

echo "Done. Log out and log in again, restart X or JUST REBOOT NOW"
