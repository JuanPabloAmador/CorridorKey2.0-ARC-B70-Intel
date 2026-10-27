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

You need only Docker and an Intel Arc GPU exposed at `/dev/dri/renderD128`.
The 5 GB of weights download themselves on first run into Docker volumes.

```bash
git clone https://github.com/JuanPabloAmador/CorridorKey2.0-ARC-B70-Intel.git
cd CorridorKey2.0-ARC-B70-Intel
cp my-clip.mp4 clips/
./corridorkey-docker my-clip.mp4 my-first-run
```

Output lands in `./outputs/my-first-run`. `<input>` is a file from
`./clips` and `<output>` the name of the folder created under `./outputs`;
both also accept absolute host paths.

A first-frame hint gives better quality and temporal stability. Put the hint
image in `./clips/` too:

```bash
cp hint.png clips/
./corridorkey-docker my-clip.mp4 my-hint-run \
  --hint_first_frame /work/in/hint.png --hint_quality 0.95
```

Arguments after `<input>` and `<output>` pass straight through to `infer.py`,
so all original CorridorKey 2.0 flags work. Paths inside those flags use the
container locations from this table:

| On your machine | Inside the extra flags |
|---|---|
| `./clips/my-clip.mp4` | `/work/in/my-clip.mp4` |
| `./outputs/my-first-run` | `/work/out/my-first-run` |

Run `./corridorkey-docker --help` for the full flag list. The wrapper
pre-applies the stable B70 recipe:

`--device xpu --hann_chunk 48 --hann_stride 24 --outputs alpha fg --no_carry_hint`

Any flag you pass explicitly wins. Advanced use such as direct
`docker compose run` or custom folders is documented in `.env.example`.

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
