# CorridorKey 2.0 en Intel Arc (XPU). Imagen autocontenida: el código va
# COPIADO dentro (no depende de mounts). Solo necesita /dev/dri + pesos.
#
# Base pineada por tag inmutable: torch 2.13.0+xpu validado en este tag.
# NUNCA reinstalar torch: rompería el build XPU.
ARG BASE_IMAGE=heroeswearkapes/comfyui-intel-xpu:2026.08.30-8a33128
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OPENCV_IO_ENABLE_OPENEXR=1 \
    # Caché de HuggingFace fuera del código (volumen en compose).
    HF_HOME=/cache/hf \
    HOME=/cache/hf

# ffmpeg (runtime) + git (solo para instalar utils3d desde GitHub).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg git libgl1 libglib2.0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Requisitos primero (capa cacheable): solo cambian si cambia requirements-xpu.txt.
# requirements-xpu.txt NO incluye torch: viene de la base.
COPY requirements-xpu.txt ./
RUN /opt/venv/bin/python -m pip install --no-cache-dir -r requirements-xpu.txt \
    && /opt/venv/bin/python -c "import torch; assert '+xpu' in torch.__version__, torch.__version__; print('torch', torch.__version__)" \
    && /opt/venv/bin/python -c "import cv2, transformers, timm; print('cv2', cv2.__version__, '| transformers', transformers.__version__)"

# El programa (los pesos viven en volúmenes, ver compose + entrypoint).
COPY corridorkey/ ./corridorkey/
COPY third_party/ ./third_party/
COPY infer.py run_interactive.py ./
COPY scripts/download_weights.py ./scripts/download_weights.py
COPY docker/entrypoint.sh /usr/local/bin/ck2-entrypoint
RUN chmod +x /usr/local/bin/ck2-entrypoint

ENTRYPOINT ["ck2-entrypoint"]
CMD ["--help"]
