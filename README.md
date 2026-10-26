# CorridorKey 2.0 on Intel Arc (XPU)

Fork of [CorridorKey2.0](https://github.com/nikopueringer/CorridorKey2.0) to run
on Intel Arc (tested: Pro B70 32 GB).

AI green/blue-screen keying: neural alpha mattes and clean foregrounds
from chroma footage.

## Status

Works at 1080p with these settings:

`--device xpu --hann_chunk 48 --hann_stride 24 --outputs alpha fg`

Still unstable: brief (~1 s) black spans can occur.

4K doesn't work yet.

## Requirements

- Intel Arc with XPU stack (`/dev/dri/renderD128`).
- Python 3.14 with XPU-enabled PyTorch (the one in Quickstart).
- ~10 GB for weights, downloaded by `scripts/download_weights.py`.

## Quickstart (Docker, recommended)

No local install needed — only Docker + an Intel Arc GPU (`/dev/dri/renderD128`).
Weights (~5 GB) download themselves on first run into Docker volumes.

```bash
git clone https://github.com/JuanPabloAmador/CorridorKey2.0-ARC-B70-Intel.git
cd CorridorKey2.0-ARC-B70-Intel
cp clips/mi.mp4 clips/          # your chroma footage goes in ./clips
./ck2 mi.mp4 p1                # output lands in ./outputs/p1 (alpha + fg)
```

With a first-frame hint (better quality and temporal stability):

```bash
./ck2 mi.mp4 p1-hint --hint_first_frame /work/in/hint.png --hint_quality 0.95
```

`./ck2` applies the stable B70 recipe (`--device xpu --hann_chunk 48
--hann_stride 24 --outputs alpha fg --no_carry_hint`); any flag you pass
explicitly wins. `./ck2 --help` shows all `infer.py` options. Advanced use
(custom paths, `docker compose run` directly): see `.env.example`.

## Quickstart (venv, no Docker)

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
