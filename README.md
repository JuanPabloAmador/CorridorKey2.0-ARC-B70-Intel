# CorridorKey 2.0 on Intel Arc (XPU)

Fork of [CorridorKey2.0](https://github.com/nikopueringer/CorridorKey2.0) to run
on Intel Arc (tested: Pro B70 32 GB).

AI green/blue-screen keying: neural alpha mattes and clean foregrounds
from chroma footage.

## Status

Works at 1080p with these settings:

`--device xpu --hann_chunk 48 --hann_stride 24 --outputs alpha fg`

4K doesn't work yet.

## Requirements

- Intel Arc with XPU stack (`/dev/dri/renderD128`).
- Python 3.14 with XPU-enabled PyTorch (the one in Quickstart).
- ~10 GB for weights, downloaded by `scripts/download_weights.py`.

## Quickstart

```bash
git clone https://github.com/JuanPabloAmador/CorridorKey2.0-ARC-B70-Intel.git
cd CorridorKey2.0-ARC-B70-Intel
python -m venv venv
source venv/bin/activate
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu
pip install -r requirements-xpu.txt
python scripts/download_weights.py
python infer.py --input clip.mp4 --output_dir out \
  --device xpu --hann_chunk 48 --hann_stride 24 --outputs alpha fg
```

## License

Same as upstream ([LICENSE](LICENSE), CC BY-NC-SA 4.0 with extra terms): free to
use incl. commercial output, same name and license; $20M+ revenue → plugin license.
