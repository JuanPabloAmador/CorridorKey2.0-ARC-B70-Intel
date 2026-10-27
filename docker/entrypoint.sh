#!/bin/bash
# Container entrypoint. Runs as root to fix permissions, then drops to
# TARGET_UID:TARGET_GID (+ render group for /dev/dri).
set -euo pipefail

APP=/app
UID_="${TARGET_UID:-1000}"
GID_="${TARGET_GID:-1000}"
RENDER_GID="${RENDER_GID:-}"
DRI="${DRI_DEVICE:-/dev/dri/renderD128}"

# 1. GPU present.
if [ ! -e "$DRI" ]; then
  echo "ERROR: $DRI not found. Expose the GPU (devices: $DRI) and retry." >&2
  exit 1
fi

# 2. Directories writable by the target user.
mkdir -p "$APP/weights" "$APP/vfms" "$HF_HOME"
chown -R "$UID_:$GID_" "$APP/weights" "$APP/vfms" "$HF_HOME"

# 3. Weights: download if missing (first boot). CK2_SKIP_DOWNLOAD=1 skips.
NEED_DL=0
[ -f "$APP/weights/corridorkey_v2.safetensors" ] || NEED_DL=1
[ -f "$APP/vfms/moge/model.pt" ] || NEED_DL=1
[ -f "$APP/vfms/rvm/pretrain_rvm_small16_256_204031069.npz" ] || NEED_DL=1
[ -d "$APP/vfms/cradio/C-RADIOv4-SO400M" ] || NEED_DL=1

# --help needs no weights: skip download.
case " $* " in *" --help "*|*" -h "*) NEED_DL=0;; esac

if [ "$NEED_DL" = "1" ]; then
  if [ "${CK2_SKIP_DOWNLOAD:-0}" = "1" ]; then
    echo "ERROR: weights missing in /app/weights and /app/vfms with CK2_SKIP_DOWNLOAD=1." >&2
    exit 1
  fi
  echo "[ck2] downloading weights (~5 GB, first run only)..."
  DROP="setpriv --reuid $UID_ --regid $GID_ --clear-groups"
  # shellcheck disable=SC2086
  $DROP /opt/venv/bin/python "$APP/scripts/download_weights.py" --package_root "$APP"
fi

# 4. Run infer.py as non-root (+ render for the GPU).
GROUPS_ARG="--clear-groups"
[ -n "$RENDER_GID" ] && GROUPS_ARG="--groups $RENDER_GID"
# shellcheck disable=SC2086
exec setpriv --reuid "$UID_" --regid "$GID_" $GROUPS_ARG \
  /opt/venv/bin/python "$APP/infer.py" "$@"
