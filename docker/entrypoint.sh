#!/bin/bash
# Entrypoint del contenedor ck2. Corre como root para preparar permisos y
# luego baja a TARGET_UID:TARGET_GID (+ grupo render para /dev/dri).
set -euo pipefail

APP=/app
UID_="${TARGET_UID:-1000}"
GID_="${TARGET_GID:-1000}"
RENDER_GID="${RENDER_GID:-}"
DRI="${DRI_DEVICE:-/dev/dri/renderD128}"

# 1. GPU presente.
if [ ! -e "$DRI" ]; then
  echo "ERROR: no existe $DRI. Expón la GPU (devices: $DRI) y reintenta." >&2
  exit 1
fi

# 2. Directorios escribibles por el usuario de destino.
mkdir -p "$APP/weights" "$APP/vfms" "$HF_HOME"
chown -R "$UID_:$GID_" "$APP/weights" "$APP/vfms" "$HF_HOME"

# 3. Pesos: descargar si faltan (primer arranque). CK2_SKIP_DOWNLOAD=1 lo omite.
NEED_DL=0
[ -f "$APP/weights/corridorkey_v2.safetensors" ] || NEED_DL=1
[ -f "$APP/vfms/moge/model.pt" ] || NEED_DL=1
[ -f "$APP/vfms/rvm/pretrain_rvm_small16_256_204031069.npz" ] || NEED_DL=1
[ -d "$APP/vfms/cradio/C-RADIOv4-SO400M" ] || NEED_DL=1

# --help no necesita pesos: no descargar.
case " $* " in *" --help "*|*" -h "*) NEED_DL=0;; esac

if [ "$NEED_DL" = "1" ]; then
  if [ "${CK2_SKIP_DOWNLOAD:-0}" = "1" ]; then
    echo "ERROR: faltan pesos en /app/weights y /app/vfms y CK2_SKIP_DOWNLOAD=1." >&2
    exit 1
  fi
  echo "[ck2] descargando pesos (~5 GB, solo la primera vez)..."
  DROP="setpriv --reuid $UID_ --regid $GID_ --clear-groups"
  # shellcheck disable=SC2086
  $DROP /opt/venv/bin/python "$APP/scripts/download_weights.py" --package_root "$APP"
fi

# 4. Ejecutar infer.py como usuario no-root (+ render para la GPU).
GROUPS_ARG="--clear-groups"
[ -n "$RENDER_GID" ] && GROUPS_ARG="--groups $RENDER_GID"
# shellcheck disable=SC2086
exec setpriv --reuid "$UID_" --regid "$GID_" $GROUPS_ARG \
  /opt/venv/bin/python "$APP/infer.py" "$@"
