#!/usr/bin/env python3
"""
ONNX → RKNN conversion for Rockchip NPU boards (default: rk3566, INT8).

Merges calibration dataset listing and RKNN-Toolkit2 build into one step.
Designed to run inside the lws-rknn-toolkit Docker image (linux/amd64).
"""
from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".heic", ".tif", ".tiff"}

PLATFORM_CHOICES = (
    "rk3562",
    "rk3566",
    "rk3568",
    "rk3576",
    "rk3588",
    "rv1126b",
    "rv1109",
    "rv1126",
    "rk1808",
)
I8_PLATFORMS = {"rk3562", "rk3566", "rk3568", "rk3576", "rk3588", "rv1126b"}
U8_PLATFORMS = {"rv1109", "rv1126", "rk1808"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert ONNX to RKNN (dataset prep + rknn-toolkit2 build)."
    )
    parser.add_argument(
        "--ai-library",
        type=Path,
        default=Path("/work/ai-library"),
        help="Root directory for ONNX, calibration zip/images, and RKNN output.",
    )
    parser.add_argument(
        "--onnx",
        type=Path,
        default=None,
        help="ONNX model path (default: sole *.onnx under --ai-library, else det_raw_head.onnx).",
    )
    parser.add_argument(
        "--platform",
        choices=PLATFORM_CHOICES,
        default="rk3566",
        help="Target SoC platform (default: rk3566).",
    )
    parser.add_argument(
        "--dtype",
        choices=("i8", "u8", "fp"),
        default="i8",
        help="Quantization dtype: i8/u8 (quantized) or fp (no quant, FP16). Default: i8.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output .rknn path (default: <onnx_stem>_<platform>_<dtype>.rknn under --ai-library).",
    )
    parser.add_argument(
        "--calib-zip",
        type=Path,
        default=None,
        help="Calibration images zip (default: sole *.zip under --ai-library).",
    )
    parser.add_argument(
        "--calib-dir",
        type=Path,
        default=None,
        help="Directory of calibration images (skip zip extraction).",
    )
    parser.add_argument(
        "--dataset-txt",
        type=Path,
        default=None,
        help="Existing dataset list (one image path per line). Skips image scan/zip extract.",
    )
    parser.add_argument(
        "--input-name",
        default="images",
        help="ONNX input tensor name (default: images).",
    )
    parser.add_argument(
        "--input-size",
        default="1,3,640,640",
        help="Input shape as comma-separated ints (default: 1,3,640,640).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose RKNN logging.",
    )
    return parser.parse_args()


def resolve_ai_library(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if not resolved.is_dir():
        raise FileNotFoundError(f"ai-library directory not found: {resolved}")
    return resolved


def find_single_glob(root: Path, pattern: str, label: str) -> Path | None:
    matches = sorted(root.glob(pattern))
    if not matches:
        return None
    if len(matches) > 1:
        names = ", ".join(p.name for p in matches)
        raise RuntimeError(f"Multiple {label} files under {root}: {names}. Pass an explicit path.")
    return matches[0]


def resolve_onnx(ai_library: Path, explicit: Path | None) -> Path:
    if explicit is not None:
        path = explicit.expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"ONNX not found: {path}")
        return path

    default = ai_library / "det_raw_head.onnx"
    if default.is_file():
        return default

    found = find_single_glob(ai_library, "*.onnx", "ONNX")
    if found is not None:
        return found

    raise FileNotFoundError(
        f"No ONNX under {ai_library}. Place det_raw_head.onnx or pass --onnx."
    )


def resolve_calib_zip(ai_library: Path, explicit: Path | None) -> Path | None:
    if explicit is not None:
        path = explicit.expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Calibration zip not found: {path}")
        return path
    return find_single_glob(ai_library, "*.zip", "calibration zip")


def default_output_path(onnx_path: Path, ai_library: Path, platform: str, dtype: str) -> Path:
    return ai_library / f"{onnx_path.stem}_{platform}_{dtype}.rknn"


def validate_dtype(platform: str, dtype: str) -> bool:
    if dtype == "fp":
        return False
    if dtype == "i8" and platform not in I8_PLATFORMS:
        raise ValueError(f"dtype i8 is not supported for platform {platform}")
    if dtype == "u8" and platform not in U8_PLATFORMS:
        raise ValueError(f"dtype u8 is not supported for platform {platform}")
    return True


def parse_input_size(raw: str) -> list[int]:
    try:
        shape = [int(part.strip()) for part in raw.split(",")]
    except ValueError as exc:
        raise ValueError(f"Invalid --input-size {raw!r}: expected comma-separated integers") from exc
    if not shape:
        raise ValueError("--input-size must contain at least one dimension")
    return shape


def collect_images(src_dir: Path, recursive: bool = True) -> list[Path]:
    if not src_dir.is_dir():
        raise NotADirectoryError(f"Not a directory: {src_dir}")

    images: list[Path] = []
    iterator = src_dir.rglob("*") if recursive else src_dir.iterdir()
    for path in iterator:
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS:
            images.append(path.resolve())
    images.sort(key=lambda p: str(p).lower())
    return images


def extract_calib_zip(zip_path: Path, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    marker = dest_dir / ".extracted"
    if marker.is_file():
        print(f"[INFO] using cached calibration extract: {dest_dir}")
        return dest_dir

    print(f"[INFO] extracting calibration zip: {zip_path} -> {dest_dir}")
    with zipfile.ZipFile(zip_path, "r") as archive:
        archive.extractall(dest_dir)
    marker.write_text(f"{zip_path.name}\n", encoding="utf-8")
    return dest_dir


def write_dataset_txt(images: list[Path], out_path: Path) -> Path:
    if not images:
        raise RuntimeError("No calibration images found; cannot build INT8 dataset list.")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [str(img) for img in images]
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[INFO] dataset list: {out_path} ({len(images)} images)")
    return out_path


def prepare_dataset(
    ai_library: Path,
    dataset_txt: Path | None,
    calib_dir: Path | None,
    calib_zip: Path | None,
    do_quant: bool,
) -> str | None:
    if not do_quant:
        print("[INFO] fp mode: skipping calibration dataset")
        return None

    if dataset_txt is not None:
        path = dataset_txt.expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Dataset txt not found: {path}")
        print(f"[INFO] using dataset txt: {path}")
        return str(path)

    cache_root = ai_library / "_cache"
    if calib_dir is not None:
        image_root = calib_dir.expanduser().resolve()
    elif calib_zip is not None:
        extract_dir = cache_root / "calib" / calib_zip.stem
        image_root = extract_calib_zip(calib_zip.resolve(), extract_dir)
    else:
        raise RuntimeError(
            "INT8 conversion requires calibration data. "
            "Place a *.zip under ai-library, or pass --calib-zip / --calib-dir / --dataset-txt."
        )

    images = collect_images(image_root, recursive=True)
    dataset_path = cache_root / "dataset.txt"
    write_dataset_txt(images, dataset_path)
    return str(dataset_path)


def convert_onnx_to_rknn(
    *,
    onnx_path: Path,
    output_path: Path,
    platform: str,
    do_quant: bool,
    dataset_path: str | None,
    input_name: str,
    input_size: list[int],
    verbose: bool,
) -> None:
    from rknn.api import RKNN

    output_path.parent.mkdir(parents=True, exist_ok=True)

    rknn = RKNN(verbose=verbose)
    try:
        print(f"[INFO] platform={platform} quant={do_quant} onnx={onnx_path}")
        print("--> config")
        rknn.config(
            mean_values=[[0, 0, 0]],
            std_values=[[255, 255, 255]],
            target_platform=platform,
        )

        print("--> load_onnx")
        ret = rknn.load_onnx(
            model=str(onnx_path),
            inputs=[input_name],
            input_size_list=[input_size],
        )
        if ret != 0:
            raise RuntimeError(f"load_onnx failed (code={ret})")

        print("--> build")
        build_kwargs = {"do_quantization": do_quant}
        if dataset_path is not None:
            build_kwargs["dataset"] = dataset_path
        ret = rknn.build(**build_kwargs)
        if ret != 0:
            raise RuntimeError(f"build failed (code={ret})")

        print(f"--> export_rknn {output_path}")
        ret = rknn.export_rknn(str(output_path))
        if ret != 0:
            raise RuntimeError(f"export_rknn failed (code={ret})")
    finally:
        rknn.release()


def main() -> int:
    args = parse_args()
    try:
        ai_library = resolve_ai_library(args.ai_library)
        onnx_path = resolve_onnx(ai_library, args.onnx)
        do_quant = validate_dtype(args.platform, args.dtype)

        output_path = (
            args.output.expanduser().resolve()
            if args.output is not None
            else default_output_path(onnx_path, ai_library, args.platform, args.dtype)
        )

        calib_zip = None if args.calib_dir or args.dataset_txt else resolve_calib_zip(ai_library, args.calib_zip)
        dataset_path = prepare_dataset(
            ai_library,
            args.dataset_txt,
            args.calib_dir,
            calib_zip,
            do_quant,
        )
        input_size = parse_input_size(args.input_size)

        convert_onnx_to_rknn(
            onnx_path=onnx_path,
            output_path=output_path,
            platform=args.platform,
            do_quant=do_quant,
            dataset_path=dataset_path,
            input_name=args.input_name,
            input_size=input_size,
            verbose=args.verbose,
        )
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] wrote {output_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
