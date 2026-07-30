#!/usr/bin/env python3
"""Validate an lws-ui process-library xlsx and generate HMI JSON assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REQUIRED_HEADERS = {"参数名称", "工艺类型", "数据类型"}
# Canonical headers match lws-ui ProcessLibColumn; aliases match ProcessLibImportProfile.
HEADER_ALIASES = {
    "扫描频率": "摆动频率",
    "摆动频率/扫描频率": "摆动频率",
    "扫描宽度": "摆动宽度",
    "摆动宽度/扫描宽度": "摆动宽度",
    "气体关闭延迟": "关气延时",
    "关气延时/气体关闭延迟": "关气延时",
    "激光关闭延迟": "关光延时",
    "关光延时/激光关闭延迟": "关光延时",
    "缓升时长": "功率缓升",
    "功率缓升/缓升时长": "功率缓升",
    "缓降时长": "功率缓降",
    "功率缓降/缓降时长": "功率缓降",
    "送丝回抽长度": "回抽长度",
    "回抽长度/送丝回抽长度": "回抽长度",
    "送丝补偿长度": "补丝长度",
    "补丝长度/送丝补偿长度": "补丝长度",
    "补丝延迟": "补丝时延",
    "补丝延时": "补丝时延",
    "送丝补偿延迟": "补丝时延",
    "补丝延迟/送丝补偿延迟": "补丝时延",
}
NUMERIC_COLUMNS = {
    "厚度",
    "激光功率",
    "激光占空比",
    "激光频率",
    "穿孔功率",
    "穿孔频率",
    "穿孔占空比",
    "摆动频率",
    "摆动宽度",
    "吹气延时",
    "关气延时",
    "关光延时",
    "补丝时延",
    "送丝时延",
    "点焊间隔",
    "点焊持续",
    "功率缓升",
    "功率缓降",
    "送丝速度",
    "回抽长度",
    "回抽速度",
    "补丝长度",
    "穿孔时长",
    "档位",
}
PARAMETER_COLUMNS = {
    "激光功率": "process.laser_power",
    "激光占空比": "process.laser_duty_cycle",
    "激光频率": "process.laser_frequency",
    "穿孔功率": "process.piercing_power",
    "穿孔频率": "process.piercing_frequency",
    "穿孔占空比": "process.piercing_duty_cycle",
    "摆动频率": "process.swing_frequency",
    "摆动宽度": "process.swing_width",
    "吹气延时": "process.blowing_delay",
    "关气延时": "process.gas_off_delay",
    "关光延时": "process.light_off_delay",
    "补丝时延": "process.wire_filling_delay",
    "送丝时延": "process.wire_feeding_delay",
    "点焊间隔": "process.spot_welding_interval",
    "点焊持续": "process.spot_welding_duration",
    "功率缓升": "process.power_ramp_up_duration",
    "功率缓降": "process.power_ramp_down_duration",
    "送丝速度": "process.wire_feeding_speed",
    "回抽长度": "process.back_draw_length",
    "回抽速度": "process.back_draw_speed",
    "补丝长度": "process.wire_filling_length",
    "穿孔时长": "process.piercing_duration",
}
PARAMETER_MULTIPLIERS = {
    # Legacy Excel uses seconds; the domain/HAL contract uses milliseconds.
    "穿孔时长": 1000,
}
PROCESS_TYPES = {
    "Continuous Weld": 0,
    "Spot Weld": 1,
    "Spot welding": 1,
    "Weld Path Clean": 2,
    "Ultra-wide Clean": 3,
    "Cut": 4,
    "CNC Cut": 5,
}
KINDS = {
    "快速模式工艺数据": "quick",
    "快速模式参数": "quick",
    "工程师模式默认数据": "engineer_preset",
    "工程师模式常用参数": "engineer_preset",
    "工程师模式内置参数": "engineer_preset",
    # Accepted only by explicit historical export tooling, not bundled xlsx.
}
# Match lws-ui ProcessDataExcelConvert (Title Case) plus historical lowercase aliases.
MATERIALS = {
    "Stainless Steel": 1,
    "Stainless steel": 1,
    "Carbon Steel": 2,
    "Carbon steel": 2,
    "Galvanized Sheet": 3,
    "Galvanized sheet": 3,
    "Galwanized sheet": 3,
    "Aluminum Alloy": 4,
    "Aluminum alloy": 4,
    "Aluminum allo": 4,
    "Brass": 5,
    "Custom": 6,
}
RANGES = {
    "process.laser_power": (0, 100),
    "process.laser_duty_cycle": (0, 100),
    "process.laser_frequency": (1, 5000),
    "process.piercing_power": (0, 100),
    "process.piercing_frequency": (0, 2000),
    "process.piercing_duty_cycle": (0, 100),
    "process.swing_frequency": (0, 220),
    "process.swing_width": (0, 6),
    "process.blowing_delay": (0, 10000),
    "process.gas_off_delay": (0, 10000),
    "process.light_off_delay": (0, 1000),
    "process.wire_filling_delay": (0, 1000),
    "process.wire_feeding_delay": (0, 2000),
    "process.spot_welding_interval": (0, 10000),
    "process.spot_welding_duration": (0, 10000),
    "process.power_ramp_up_duration": (0, 1000),
    "process.power_ramp_down_duration": (0, 1000),
    "process.wire_feeding_speed": (0, 50),
    "process.back_draw_length": (0, 35),
    "process.back_draw_speed": (3, 100),
    "process.wire_filling_length": (0, 35),
    "process.piercing_duration": (0, 2000),
}


def column_index(cell_reference: str) -> int:
    letters = re.match(r"[A-Z]+", cell_reference)
    if letters is None:
        raise ValueError(f"invalid xlsx cell reference: {cell_reference}")
    result = 0
    for char in letters.group(0):
        result = result * 26 + ord(char) - ord("A") + 1
    return result - 1


def xlsx_rows(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        shared: list[str] = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ElementTree.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in root.findall("m:si", NS):
                shared.append("".join(node.text or "" for node in item.findall(".//m:t", NS)))
        workbook = ElementTree.fromstring(archive.read("xl/workbook.xml"))
        first_sheet = workbook.find("m:sheets/m:sheet", NS)
        if first_sheet is None:
            raise ValueError("xlsx has no worksheet")
        relation_id = first_sheet.attrib[
            "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
        ]
        relations = ElementTree.fromstring(
            archive.read("xl/_rels/workbook.xml.rels")
        )
        target = next(
            rel.attrib["Target"]
            for rel in relations
            if rel.attrib["Id"] == relation_id
        )
        sheet_path = target.lstrip("/")
        if not sheet_path.startswith("xl/"):
            sheet_path = "xl/" + sheet_path
        root = ElementTree.fromstring(archive.read(sheet_path))
        result: list[list[str]] = []
        for row in root.findall(".//m:sheetData/m:row", NS):
            values: dict[int, str] = {}
            for cell in row.findall("m:c", NS):
                index = column_index(cell.attrib["r"])
                cell_type = cell.attrib.get("t")
                if cell_type == "inlineStr":
                    value = "".join(
                        node.text or "" for node in cell.findall(".//m:t", NS)
                    )
                else:
                    node = cell.find("m:v", NS)
                    value = "" if node is None else (node.text or "")
                    if cell_type == "s" and value:
                        value = shared[int(value)]
                values[index] = value.strip()
            width = max(values, default=-1) + 1
            result.append([values.get(index, "") for index in range(width)])
        return result


def number(value: str, header: str, row_number: int) -> int | float | None:
    if not value:
        return None
    try:
        parsed = float(value)
    except ValueError as error:
        raise ValueError(
            f"row {row_number}: {header} must be numeric, got {value!r}"
        ) from error
    return int(parsed) if parsed.is_integer() else parsed


def canonical_header(raw: str) -> str:
    trimmed = raw.strip()
    return HEADER_ALIASES.get(trimmed, trimmed)


def convert(rows: list[list[str]], version: str) -> list[dict[str, object]]:
    if not rows:
        raise ValueError("xlsx is empty")
    headers = [canonical_header(value) for value in rows[0]]
    duplicates = sorted({value for value in headers if value and headers.count(value) > 1})
    if duplicates:
        raise ValueError(f"duplicate headers: {duplicates}")
    missing = sorted(REQUIRED_HEADERS - set(headers))
    if missing:
        raise ValueError(f"missing required headers: {missing}")
    indexes = {header: index for index, header in enumerate(headers) if header}
    presets: list[dict[str, object]] = []
    quick_keys: set[tuple[object, ...]] = set()
    for row_number, cells in enumerate(rows[1:], start=2):
        if not any(value.strip() for value in cells):
            continue

        def text(header: str) -> str:
            index = indexes.get(header)
            return "" if index is None or index >= len(cells) else cells[index].strip()

        name = text("参数名称")
        process_text = text("工艺类型")
        data_text = text("数据类型")
        if not name:
            raise ValueError(f"row {row_number}: 参数名称 is required")
        if process_text not in PROCESS_TYPES:
            raise ValueError(f"row {row_number}: unknown 工艺类型 {process_text!r}")
        if data_text not in KINDS:
            raise ValueError(f"row {row_number}: unsupported 数据类型 {data_text!r}")
        material_text = text("材料")
        if material_text and material_text not in MATERIALS:
            raise ValueError(f"row {row_number}: unknown 材料 {material_text!r}")

        parameters: dict[str, int | float] = {}
        for header, key in PARAMETER_COLUMNS.items():
            value = number(text(header), header, row_number)
            if value is None:
                continue
            value *= PARAMETER_MULTIPLIERS.get(header, 1)
            if isinstance(value, float) and value.is_integer():
                value = int(value)
            lower, upper = RANGES[key]
            if key == "process.swing_width" and PROCESS_TYPES[process_text] == 3:
                lower, upper = 0, 30
            if not lower <= value <= upper:
                raise ValueError(
                    f"row {row_number}: {header}={value} outside {lower}..{upper}"
                )
            parameters[key] = value
        thickness = number(text("厚度"), "厚度", row_number)
        gear = number(text("档位"), "档位", row_number)
        if gear is not None and not isinstance(gear, int):
            raise ValueError(f"row {row_number}: 档位 must be an integer")
        kind = KINDS[data_text]
        process_type = PROCESS_TYPES[process_text]
        material_type = MATERIALS.get(material_text)
        swing_width = parameters.get("process.swing_width")
        identity = json.dumps(
            [
                version,
                kind,
                process_type,
                material_type,
                thickness,
                swing_width,
                gear,
                name,
            ],
            ensure_ascii=False,
            separators=(",", ":"),
        )
        digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()
        uuid = (
            f"{digest[:8]}-{digest[8:12]}-{digest[12:16]}-"
            f"{digest[16:20]}-{digest[20:32]}"
        )
        preset: dict[str, object] = {
            "uuid": uuid,
            "name": name,
            "kind": kind,
            "process_type": process_type,
            "material_type": material_type,
            "material_name": text("材质名称") or None,
            "thickness": thickness,
            "gear": gear,
            "parameters": parameters,
        }
        if kind == "quick":
            # Cleaning rows key on swing width; weld/cut rows key on thickness.
            key = (process_type, material_type, thickness, swing_width, gear)
            if key in quick_keys:
                raise ValueError(f"row {row_number}: duplicate quick lookup {key}")
            quick_keys.add(key)
        presets.append(preset)
    if not presets:
        raise ValueError("xlsx contains no process rows")
    return presets


VERSION_RE = re.compile(r"^\d+(?:\.\d+){0,2}$")
# Flutter ship asset key prefix (must match pubspec + ProcessLibraryImporter).
DEFAULT_ASSET_KEY_PREFIX = "assets/.generated/process-library"


def normalize_version_basename(stem: str) -> str:
    """Strip optional leading v/V from an Excel basename stem."""
    if len(stem) >= 2 and stem[0] in "vV" and stem[1].isdigit():
        return stem[1:]
    return stem


def compare_versions(left: str, right: str) -> int:
    """Numeric semver compare aligned with Dart ProcessLibraryImporter._compareVersions."""
    if not VERSION_RE.fullmatch(left) or not VERSION_RE.fullmatch(right):
        raise ValueError(f"invalid semantic version: {left!r} / {right!r}")

    def parts(value: str) -> list[int]:
        return [int(p) for p in value.split("+", 1)[0].split("-", 1)[0].split(".")]

    a = parts(left)
    b = parts(right)
    for i in range(3):
        ai = a[i] if i < len(a) else 0
        bi = b[i] if i < len(b) else 0
        if ai != bi:
            return (ai > bi) - (ai < bi)
    # Match Dart ProcessLibraryImporter._compareVersions: equal when numeric parts match.
    return 0


def model_dir_to_product_model(dirname: str) -> str:
    return dirname.replace("_", " ")


def write_library_json(
    *,
    xlsx: Path,
    version: str,
    output_dir: Path,
    relative_json: str,
) -> tuple[str, str, int]:
    """Write versioned JSON under output_dir; return (relative path, sha256, row_count)."""
    if not VERSION_RE.fullmatch(version):
        raise ValueError(f"invalid semantic version: {version!r}")
    presets = convert(xlsx_rows(xlsx), version)
    dest = output_dir / relative_json
    dest.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": 1,
        "library_version": version,
        "presets": presets,
    }
    payload_bytes = (
        json.dumps(payload, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
        + "\n"
    ).encode("utf-8")
    dest.write_bytes(payload_bytes)
    digest = hashlib.sha256(payload_bytes).hexdigest()
    return relative_json.replace("\\", "/"), digest, len(presets)


def ship_from_process_libraries(
    source_root: Path,
    output_dir: Path,
    asset_key_prefix: str = DEFAULT_ASSET_KEY_PREFIX,
) -> int:
    """Convert newest Excel per model dir into output_dir + ship-only manifest."""
    if not source_root.is_dir():
        raise ValueError(f"missing process-library root: {source_root}")

    libraries: list[dict] = []
    model_dirs = sorted(
        p for p in source_root.iterdir() if p.is_dir() and not p.name.startswith(".")
    )
    if not model_dirs:
        raise ValueError(f"no model directories under {source_root}")

    for model_dir in model_dirs:
        unexpected = [
            p.name
            for p in model_dir.iterdir()
            if p.is_file() and p.suffix.lower() != ".xlsx" and not p.name.startswith(".")
        ]
        if unexpected:
            raise ValueError(
                f"{model_dir}: unexpected non-xlsx files: {', '.join(sorted(unexpected))}"
            )
        candidates: list[tuple[str, Path]] = []
        for xlsx in model_dir.glob("*.xlsx"):
            version = normalize_version_basename(xlsx.stem)
            if not VERSION_RE.fullmatch(version):
                raise ValueError(f"invalid version basename: {xlsx.name}")
            candidates.append((version, xlsx))
        if not candidates:
            raise ValueError(f"{model_dir}: no .xlsx files")
        candidates.sort(key=lambda item: item[0], reverse=False)
        # Pick newest via compare_versions (stable against naive string sort).
        best_version, best_xlsx = candidates[0]
        for version, path in candidates[1:]:
            if compare_versions(version, best_version) > 0:
                best_version, best_xlsx = version, path

        product_model = model_dir_to_product_model(model_dir.name)
        relative_json = f"{model_dir.name}/{best_version}.json"
        asset_rel, digest, row_count = write_library_json(
            xlsx=best_xlsx,
            version=best_version,
            output_dir=output_dir,
            relative_json=relative_json,
        )
        prefix = asset_key_prefix.rstrip("/")
        libraries.append(
            {
                "source": "bundled",
                "library_version": best_version,
                "asset": f"{prefix}/{asset_rel}",
                "content_sha256": digest,
                "supported_models": [product_model],
                "row_count": row_count,
            }
        )
        print(
            f"ship {model_dir.name}: {best_xlsx.name} -> {asset_rel} "
            f"({row_count} rows, sha256={digest})"
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {"schema_version": 1, "libraries": libraries}
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {output_dir / 'manifest.json'} ({len(libraries)} libraries)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate process-library xlsx and generate HMI JSON / ship assets."
    )
    parser.add_argument(
        "xlsx",
        type=Path,
        nargs="?",
        help="single workbook (omit when using --ship-from)",
    )
    parser.add_argument("--version", help="library_version for single-workbook mode")
    parser.add_argument(
        "--models",
        help="comma-separated product.ini MODEL values, or * (single-workbook mode)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("app/lws_hmi/assets/.generated/process-library"),
    )
    parser.add_argument(
        "--model-dir",
        help="model directory name for JSON path (default: first --models with spaces→_)",
    )
    parser.add_argument(
        "--asset-key-prefix",
        default=DEFAULT_ASSET_KEY_PREFIX,
        help="Flutter asset key prefix written into manifest.json",
    )
    parser.add_argument(
        "--ship-from",
        type=Path,
        help="process-library root: convert newest xlsx per model into --output-dir",
    )
    parser.add_argument(
        "--no-manifest",
        action="store_true",
        help="single-workbook mode: write JSON only (no manifest.json)",
    )
    args = parser.parse_args()

    if args.ship_from is not None:
        return ship_from_process_libraries(
            args.ship_from,
            args.output_dir,
            asset_key_prefix=args.asset_key_prefix,
        )

    if args.xlsx is None or args.version is None or args.models is None:
        raise ValueError("xlsx, --version, and --models are required unless --ship-from")

    models = [value.strip() for value in args.models.split(",") if value.strip()]
    if not models:
        raise ValueError("--models must list at least one model")
    model_dir = args.model_dir or models[0].replace(" ", "_")
    relative_json = f"{model_dir}/{args.version}.json"
    asset_rel, digest, row_count = write_library_json(
        xlsx=args.xlsx,
        version=args.version,
        output_dir=args.output_dir,
        relative_json=relative_json,
    )
    if not args.no_manifest:
        prefix = args.asset_key_prefix.rstrip("/")
        manifest = {
            "schema_version": 1,
            "libraries": [
                {
                    "source": "bundled",
                    "library_version": args.version,
                    "asset": f"{prefix}/{asset_rel}",
                    "content_sha256": digest,
                    "supported_models": models,
                    "row_count": row_count,
                }
            ],
        }
        (args.output_dir / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(f"generated {asset_rel}: {row_count} rows, sha256={digest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, zipfile.BadZipFile) as error:
        print(f"process-library conversion failed: {error}", file=sys.stderr)
        raise SystemExit(2)
