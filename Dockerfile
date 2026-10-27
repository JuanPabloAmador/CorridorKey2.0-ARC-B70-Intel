# CorridorKey 2.0 on Intel Arc (XPU). Self-contained first-party image:
# Ubuntu (Canonical) + Intel GitHub releases (compute-runtime, IGC,
# level-zero) + official PyTorch wheels. Zero third-party images.
# Code is COPYied in (needs no mounts).
#
# torch 2.13.0+xpu: same version validated on the B70 (official wheels,
# download.pytorch.org/whl/xpu). Python 3.12 (Ubuntu 24.04): allows using
# upstream requirements.txt as is (numpy<2, transformers<5 have wheels
# for 3.12; none exist for 3.14).
ARG UBUNTU_DIGEST=sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac
FROM ubuntu:24.04@${UBUNTU_DIGEST}

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    OPENCV_IO_ENABLE_OPENEXR=1 \
    HF_HOME=/cache/hf \
    HOME=/cache/hf \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}"

# Ubuntu official repos only. The GPU user-mode stack (compute runtime)
# comes from pinned intel/compute-runtime GitHub debs (first-party Intel,
# same version as the validated B70 env): Intel's apt repo for noble is
# stuck at 25.18, incompatible with new kernels (zeInit fails).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget \
    python3.12 python3.12-venv \
    ffmpeg git libgl1 libglib2.0 \
    ocl-icd-libopencl1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# GPU stack following the vLLM Dockerfile.xpu recipe (Ubuntu 24.04): IGC +
# compute-runtime + Level Zero loader, all pinned by GitHub release.
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

# venv + official XPU torch (NEVER from another index: breaks the XPU build).
ARG TORCH_XPU_VERSION=2.13.0+xpu
RUN python3.12 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/python -m pip install --no-cache-dir \
        "torch==${TORCH_XPU_VERSION}" --index-url https://download.pytorch.org/whl/xpu \
    && /opt/venv/bin/python -c "import torch; assert '+xpu' in torch.__version__, torch.__version__; print('torch', torch.__version__)"

WORKDIR /app

# Exact upstream requirements (first cacheable layer).
# timm goes with --no-deps: its metadata pulls PyPI torchvision, which would
# uninstall torch+xpu to install the CUDA build. At runtime timm only uses
# torch (verified in the e2e test); torchvision is not imported on the
# inference path (only in data_augmentation.py, dead code).
COPY requirements.txt ./
RUN grep -v -E "^timm([<>= ]|$)" requirements.txt > /tmp/req-notimm.txt \
    && /opt/venv/bin/python -m pip install --no-cache-dir -r /tmp/req-notimm.txt \
    && /opt/venv/bin/python -m pip install --no-cache-dir --no-deps "timm>=1.0" \
    && /opt/venv/bin/python -m pip install --no-cache-dir --no-deps --index-url https://download.pytorch.org/whl/xpu "torchvision==0.28.0+xpu" \
    && /opt/venv/bin/python -m pip install --no-cache-dir "opencv-python==4.14.0.94" \
    && /opt/venv/bin/python -c "import torch, timm; assert '+xpu' in torch.__version__, torch.__version__; print('torch', torch.__version__, '| timm', timm.__version__)" \
    && /opt/venv/bin/python -c "import cv2, transformers; print('cv2', cv2.__version__, '| transformers', transformers.__version__)" \
    && /opt/venv/bin/python -c "import cv2, numpy as np; assert cv2.imwrite('/tmp/t.exr', (np.ones((8, 8, 3), np.float32) * 0.5)), 'no EXR writer'; print('EXR ok')"

# The program (weights live in volumes, see compose + entrypoint).
COPY corridorkey/ ./corridorkey/
COPY third_party/ ./third_party/
COPY infer.py run_interactive.py ./
COPY scripts/download_weights.py ./scripts/download_weights.py
COPY docker/entrypoint.sh /usr/local/bin/ck2-entrypoint
RUN chmod +x /usr/local/bin/ck2-entrypoint

ENTRYPOINT ["ck2-entrypoint"]
CMD ["--help"]
