#!/usr/bin/env python3
"""Stream a file to stdout and report transfer progress on stderr.

Supports overall progress across multiple sequential streams via --offset/--total.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path


def format_bytes(value: int) -> str:
    units = ("B", "KiB", "MiB", "GiB")
    size = float(value)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} GiB"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="file to stream to stdout")
    parser.add_argument(
        "--label",
        default="",
        help="progress label (default: file name)",
    )
    parser.add_argument(
        "--offset",
        type=int,
        default=0,
        help="bytes already streamed in this overall session",
    )
    parser.add_argument(
        "--total",
        type=int,
        default=0,
        help="overall session total bytes (0 = this file only)",
    )
    args = parser.parse_args()

    path = args.file
    if not path.is_file():
        print(f"ERROR: missing file: {path}", file=sys.stderr)
        return 2

    file_total = path.stat().st_size
    label = args.label or path.name
    overall_total = args.total if args.total > 0 else file_total
    overall_offset = max(0, args.offset)
    sent = 0
    started = time.monotonic()
    next_percent = 0
    chunk_size = min(1024 * 1024, max(1, file_total // 200 if file_total else 1))
    progress_width = 0
    progress_rendered = False

    try:
        with path.open("rb") as source:
            while chunk := source.read(chunk_size):
                sys.stdout.buffer.write(chunk)
                sent += len(chunk)
                overall_sent = overall_offset + sent
                percent = (
                    100
                    if overall_total == 0
                    else min(100, overall_sent * 100 // overall_total)
                )
                if percent >= next_percent or sent == file_total:
                    elapsed = max(time.monotonic() - started, 0.001)
                    rate = int(sent / elapsed)
                    message = (
                        f"  {label}: {percent:3d}% "
                        f"({format_bytes(overall_sent)}/{format_bytes(overall_total)}, "
                        f"{format_bytes(rate)}/s)"
                    )
                    progress_width = max(progress_width, len(message))
                    sys.stderr.write(f"\r{message:<{progress_width}}")
                    sys.stderr.flush()
                    progress_rendered = True
                    next_percent = min(100, percent + 1)
        sys.stdout.buffer.flush()
    except BrokenPipeError:
        if progress_rendered:
            sys.stderr.write("\n")
        return 1

    if progress_rendered:
        sys.stderr.write("\n")
        sys.stderr.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
