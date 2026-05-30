#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: intel-legacy-fix.sh
# DESCRIPCIÓN: Corrige la corrupción del búfer de video (patrón de líneas verticales)
#              en arquitecturas Intel Legacy mediante el downgrade controlado a DRI2,
#              UXA y el backend clásico de Mesa (Mesa Amber).
# AUTOR: netenebrae
# ==============================================================================

# ------------------------------------------------------------------------------
# OBSERVACIONES: MESA AMBER + MODESETTING (SIN VARIABLES)
# ------------------------------------------------------------------------------
# Esta configuración es el resultado de pruebas directas en el hardware,
# demostrando ser la combinación con mayor estabilidad y rendimiento. FASE DE PRUEBAS, AUN NO ESTÁ APLICADA AL SCRIPT.
#
# REQUISITOS Y COMPORTAMIENTO:
# 1. Gráficos base: Requiere 'mesa-amber' y 'lib32-mesa-amber' instalados.
# 2. Driver Xorg: Utiliza 'modesetting' (nativo de Xorg), eliminando por completo el paquete 'xf86-video-intel' para evitar artefactos en la GPU.
# 3. Sincronización: Activa 'DRI 3' y 'TearFree' para eliminar el desgarro visual.
# 4. Simplificación: No requiere variables de entorno en /etc/environment.d/ ni configuraciones personalizadas en /etc/sddm.conf.d/.
# ------------------------------------------------------------------------------


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
SDDM_CONF_DIR="/etc/sddm.conf.d"
SDDM_CONF_FILE="$SDDM_CONF_DIR/10-mesa-legacy.conf"

timestamp=$(date +%Y%m%d-%H%M%S)

enable_sddm_fix=0

for arg in "$@"; do
  case "$arg" in
    --sddm)
      enable_sddm_fix=1
      ;;
  esac
done

install_mesa_amber() {
  local mesa_pkgs=(mesa-amber lib32-mesa-amber)
  local conflict_pkgs=()

  if pacman -Q mesa >/dev/null 2>&1; then
    conflict_pkgs+=(mesa)
  fi

  if pacman -Q lib32-mesa >/dev/null 2>&1; then
    conflict_pkgs+=(lib32-mesa)
  fi

  if ! pacman -S --noconfirm --needed "${mesa_pkgs[@]}"; then
    if ((${#conflict_pkgs[@]})); then
      pacman -Rdd --noconfirm "${conflict_pkgs[@]}"
      pacman -S --noconfirm --needed "${mesa_pkgs[@]}"
    else
      return 1
    fi
  fi
}

apply_sddm_greeter_fix() {
  local greeter_env="LIBGL_DRI3_DISABLE=1,MESA_LOADER_DRIVER_OVERRIDE=i965,QT_QUICK_BACKEND=software,QT_OPENGL=software,LIBGL_ALWAYS_SOFTWARE=1,MESA_GL_VERSION_OVERRIDE=3.0,MESA_GLSL_VERSION_OVERRIDE=130"

  mkdir -p "$SDDM_CONF_DIR"
  cat > "$SDDM_CONF_FILE" <<EOF
[General]
GreeterEnvironment=$greeter_env
EOF
}

# ------------------------------------------------------------------------------
# GESTIÓN DE DEPENDENCIAS: MESA AMBER (DRIVERS DE GRADUADOS / LEGACY)
# ------------------------------------------------------------------------------
# El driver principal de Mesa removió el soporte nativo de hardware clásico.
# Es mandatorio instalar el fork oficial 'mesa-amber' para recuperar el soporte 3D real.
# ------------------------------------------------------------------------------
pacman -S --needed --noconfirm xf86-video-intel
install_mesa_amber

# Asegurar la existencia de los directorios del sistema de archivos
mkdir -p "$XORG_CONF_DIR" "$ENV_DIR"

# Mecanismo de respaldo (Backup) preventivo de la configuración previa de Xorg
if [[ -f "$XORG_CONF_FILE" ]]; then
  cp "$XORG_CONF_FILE" "${XORG_CONF_FILE}.bak.${timestamp}"
fi

# ------------------------------------------------------------------------------
# CONFIGURACIÓN DE XORG (SERVIDOR GRÁFICO X11)
# ------------------------------------------------------------------------------
# - AccelMethod "sna": Habilita SandyBridge New Acceleration. Es el método más 
#   eficiente para Intel Gen 6, optimizando el balanceo de carga entre CPU y GPU.
#   Se utiliza junto a mesa-amber para garantizar estabilidad y máxima fluidez.
# - TearFree "true": Habilita el doble búfer nativo para eliminar el desgarro 
#   de pantalla (tearing) durante el scroll y reproducción de video.
# - DRI "2": Fuerza el uso de Direct Rendering Infrastructure 2. Mantiene una 
#   sincronización estricta de la memoria de video, ideal para hardware legacy.
# ------------------------------------------------------------------------------
cat > "$XORG_CONF_FILE" <<'EOF'
Section "Device"
    Identifier "Intel Graphics"
    Driver "intel"
    Option "AccelMethod" "sna"
    Option "TearFree" "true"
    Option "DRI" "3"
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
# Testing DIR Disable. Default = 0
cat > "$ENV_FILE" <<'EOF'
MESA_LOADER_DRIVER_OVERRIDE=i965
LIBGL_DRI3_DISABLE=1
EOF

if [[ "$enable_sddm_fix" == "1" ]]; then
  apply_sddm_greeter_fix
fi

echo "Done. Log out and log in again, restart X or JUST REBOOT NOW"
