# CorridorKey 2.0 en Intel Arc (XPU). Imagen autocontenida de primeros:
# Ubuntu (Canonical) + releases de GitHub de Intel (compute-runtime, IGC,
# level-zero) + wheels oficiales de PyTorch. Cero imagenes de terceros.
# El codigo va COPIADO dentro (no necesita mounts).
#
# torch 2.13.0+xpu: misma version validada en la B70 (wheels oficiales,
# download.pytorch.org/whl/xpu). Python 3.12 (Ubuntu 24.04): permite usar
# requirements.txt del upstream tal cual (numpy<2, transformers<5 tienen
# wheels para 3.12; en 3.14 no existen).
ARG UBUNTU_DIGEST=sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac
FROM ubuntu:24.04@${UBUNTU_DIGEST}

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OPENCV_IO_ENABLE_OPENEXR=1 \
    HF_HOME=/cache/hf \
    HOME=/cache/hf \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}"

# Solo repos oficiales de Ubuntu. El user-mode de la GPU (compute runtime)
# viene de debs pineados de GitHub intel/compute-runtime (first-party Intel,
# misma version que el entorno B70 validado): el repo apt de Intel para
# noble se quedo en 25.18, incompatible con kernels nuevos (zeInit falla).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget \
    python3.12 python3.12-venv \
    ffmpeg git libgl1 libglib2.0 \
    ocl-icd-libopencl1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Stack de GPU segun receta de vLLM Dockerfile.xpu (Ubuntu 24.04): IGC +
# compute-runtime + loader Level Zero, todo pineado por release de GitHub.
ARG NEO_VERSION=26.05.37020.3
ARG IGC_VERSION=2.28.4
ARG IGC_BUILD=20760
ARG IGDM_VERSION=22.9.0
ARG L0_VERSION=1.32.0
RUN cd /tmp && mkdir -p neo && cd neo \
    && wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v${IGC_VERSION}/intel-igc-core-2_${IGC_VERSION}+${IGC_BUILD}_amd64.deb \
        https://github.com/intel/intel-graphics-compiler/releases/download/v${IGC_VERSION}/intel-igc-opencl-2_${IGC_VERSION}+${IGC_BUILD}_amd64.deb \
        https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/libigdgmm12_${IGDM_VERSION}_amd64.deb \
        https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/libze-intel-gpu1_${NEO_VERSION}-0_amd64.deb \
        https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/intel-ocloc_${NEO_VERSION}-0_amd64.deb \
        https://github.com/intel/compute-runtime/releases/download/${NEO_VERSION}/intel-opencl-icd_${NEO_VERSION}-0_amd64.deb \
        https://github.com/oneapi-src/level-zero/releases/download/v${L0_VERSION}/libze1_${L0_VERSION}+u24.04_amd64.deb \
    && dpkg -i *.deb && cd /tmp && rm -rf neo

# venv + torch XPU oficial (NUNCA de otro indice: rompería el build XPU).
ARG TORCH_XPU_VERSION=2.13.0+xpu
RUN python3.12 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/python -m pip install --no-cache-dir \
        "torch==${TORCH_XPU_VERSION}" --index-url https://download.pytorch.org/whl/xpu \
    && /opt/venv/bin/python -c "import torch; assert '+xpu' in torch.__version__, torch.__version__; print('torch', torch.__version__)"

WORKDIR /app

# Requisitos exactos del upstream (primera capa cacheable).
# timm va con --no-deps: su metadato arrastra torchvision de PyPI, que a su
# vez desinstalaría torch+xpu para poner el build CUDA. En runtime timm solo
# usa torch (verificado en el test e2e); torchvision no se importa en el
# camino de inferencia (solo en data_augmentation.py, código muerto).
COPY requirements.txt ./
RUN grep -v -E "^timm([<>= ]|$)" requirements.txt > /tmp/req-notimm.txt \
    && /opt/venv/bin/python -m pip install --no-cache-dir -r /tmp/req-notimm.txt \
    && /opt/venv/bin/python -m pip install --no-cache-dir --no-deps "timm>=1.0" \
    && /opt/venv/bin/python -m pip install --no-cache-dir --no-deps --index-url https://download.pytorch.org/whl/xpu "torchvision==0.28.0+xpu" \
    && /opt/venv/bin/python -m pip install --no-cache-dir "opencv-python==4.14.0.94" \
    && /opt/venv/bin/python -c "import torch, timm; assert '+xpu' in torch.__version__, torch.__version__; print('torch', torch.__version__, '| timm', timm.__version__)" \
    && /opt/venv/bin/python -c "import cv2, transformers; print('cv2', cv2.__version__, '| transformers', transformers.__version__)" \
    && /opt/venv/bin/python -c "import cv2, numpy as np; assert cv2.imwrite('/tmp/t.exr', (np.ones((8, 8, 3), np.float32) * 0.5)), 'sin writer EXR'; print('EXR ok')"

# El programa (los pesos viven en volúmenes, ver compose + entrypoint).
COPY corridorkey/ ./corridorkey/
COPY third_party/ ./third_party/
COPY infer.py run_interactive.py ./
COPY scripts/download_weights.py ./scripts/download_weights.py
COPY docker/entrypoint.sh /usr/local/bin/ck2-entrypoint
RUN chmod +x /usr/local/bin/ck2-entrypoint

ENTRYPOINT ["ck2-entrypoint"]
CMD ["--help"]
