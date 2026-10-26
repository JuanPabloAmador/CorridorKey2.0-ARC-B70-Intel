"""Device backend: resolve auto/cuda/xpu/cpu and route torch backend calls."""
from __future__ import annotations

import torch

VALID_DEVICES = ("auto", "cuda", "xpu", "cpu")


def resolve_device(name: str | torch.device) -> torch.device:
    """'auto' -> cuda if present, else xpu if present, else cpu."""
    if isinstance(name, torch.device):
        return name
    name = str(name or "auto").lower()
    if name == "auto":
        if torch.cuda.is_available():
            return torch.device("cuda")
        if hasattr(torch, "xpu") and torch.xpu.is_available():
            return torch.device("xpu")
        return torch.device("cpu")
    if name == "cuda":
        if not torch.cuda.is_available():
            raise RuntimeError(
                "CUDA requested but torch.cuda.is_available() is False.")
        return torch.device("cuda")
    if name == "xpu":
        if not (hasattr(torch, "xpu") and torch.xpu.is_available()):
            raise RuntimeError(
                "XPU requested but torch.xpu.is_available() is False. "
                "Use an Intel XPU PyTorch build and pass the GPU device "
                "(e.g. /dev/dri/renderD128).")
        return torch.device("xpu")
    if name == "cpu":
        return torch.device("cpu")
    raise ValueError(f"unsupported device {name!r}; choose from {VALID_DEVICES}")


def _backend(device: torch.device | str):
    kind = device.type if isinstance(device, torch.device) else str(device)
    if kind == "cuda":
        return torch.cuda
    if kind == "xpu":
        return torch.xpu
    return None


def empty_cache(device: torch.device | str) -> None:
    be = _backend(device)
    if be is not None:
        be.empty_cache()


def synchronize(device: torch.device | str) -> None:
    be = _backend(device)
    if be is not None:
        be.synchronize()


def mem_free_reserved(device: torch.device | str) -> tuple[int, int]:
    """(free_bytes, reserved_bytes) for the given device. CPU -> (0, 0)."""
    be = _backend(device)
    if be is None:
        return 0, 0
    free, _total = be.mem_get_info()
    return free, be.memory_reserved()


def autocast_for(device: torch.device | str):
    """bfloat16 autocast context for cuda/xpu/cpu."""
    kind = device.type if isinstance(device, torch.device) else str(device)
    return torch.autocast(kind, dtype=torch.bfloat16)


def active_device(model) -> torch.device:
    """Device the model currently lives on (all submodules move together)."""
    return next(model.parameters()).device
