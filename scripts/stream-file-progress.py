#!/usr/bin/env python3
"""Stream a file to stdout and report transfer progress on stderr."""

from __future__ import annotations

import os
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
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <file>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    total = path.stat().st_size
    sent = 0
    started = time.monotonic()
    next_percent = 0
    # Keep chunks below half a percent so no displayed integer percentage is
    # skipped; cap at 1 MiB for large rootfs images.
    chunk_size = min(1024 * 1024, max(1, total // 200))
    progress_width = 0
    progress_rendered = False

    try:
        with path.open("rb") as source:
            while chunk := source.read(chunk_size):
                sys.stdout.buffer.write(chunk)
                sent += len(chunk)
                percent = 100 if total == 0 else sent * 100 // total
                if percent >= next_percent or sent == total:
                    elapsed = max(time.monotonic() - started, 0.001)
                    rate = int(sent / elapsed)
                    message = (
                        f"  {path.name}: {percent:3d}% "
                        f"({format_bytes(sent)}/{format_bytes(total)}, "
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
