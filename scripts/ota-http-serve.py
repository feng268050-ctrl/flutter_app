#!/usr/bin/env python3
"""Ephemeral OTA HTTP server for host make upgrade.

Serves only allowlisted files under --dir by reading them in chunks.
Stdout:
  line 1 = base URL (http://bind:port/)
  later  = TRANSFER_COMPLETE once archive + .sig have each been fully GET once
Stderr: transfer progress while writing each response body
        (same style as stream-file-progress.py).
"""

from __future__ import annotations

import argparse
import os
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


ALLOWED_NAMES = frozenset(
    {
        "ota-package.tar.gz",
        "ota-package.tar.gz.sig",
    }
)

_session_lock = threading.Lock()
_session_sent = 0
_session_total = 0
_completed_names: set[str] = set()
_transfer_complete_emitted = False


def format_bytes(value: int) -> str:
    units = ("B", "KiB", "MiB", "GiB")
    size = float(value)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} GiB"


def _progress_line(
    label: str,
    overall_sent: int,
    overall_total: int,
    rate: int,
    width: int,
) -> tuple[str, int]:
    percent = (
        100
        if overall_total <= 0
        else min(100, overall_sent * 100 // overall_total)
    )
    message = (
        f"  {label}: {percent:3d}% "
        f"({format_bytes(overall_sent)}/{format_bytes(overall_total)}, "
        f"{format_bytes(rate)}/s)"
    )
    width = max(width, len(message))
    return f"\r{message:<{width}}", width


def _mark_file_complete(name: str) -> None:
    global _transfer_complete_emitted
    with _session_lock:
        _completed_names.add(name)
        done = ALLOWED_NAMES.issubset(_completed_names)
        if done and not _transfer_complete_emitted:
            _transfer_complete_emitted = True
            emit = True
        else:
            emit = False
    if emit:
        print("TRANSFER_COMPLETE", flush=True)


class OtaRequestHandler(BaseHTTPRequestHandler):
    serve_dir: Path = Path(".")
    chunk_size: int = 1024 * 1024

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        if os.environ.get("OTA_HTTP_VERBOSE"):
            super().log_message(format, *args)

    def do_GET(self) -> None:  # noqa: N802
        path = unquote(urlparse(self.path).path)
        name = path.rsplit("/", 1)[-1]
        if name not in ALLOWED_NAMES or ".." in path or path.startswith("//"):
            self.send_error(404, "Not found")
            return

        file_path = (self.serve_dir / name).resolve()
        try:
            file_path.relative_to(self.serve_dir.resolve())
        except ValueError:
            self.send_error(404, "Not found")
            return
        if not file_path.is_file():
            self.send_error(404, "Not found")
            return

        file_size = file_path.stat().st_size
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(file_size))
        self.send_header("Accept-Ranges", "none")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

        label = name
        sent = 0
        started = time.monotonic()
        next_percent = 0
        progress_width = 0
        progress_rendered = False

        try:
            with file_path.open("rb") as source:
                while True:
                    chunk = source.read(self.chunk_size)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    sent += len(chunk)
                    with _session_lock:
                        global _session_sent
                        _session_sent += len(chunk)
                        overall_sent = _session_sent
                        overall_total = _session_total or file_size
                    percent = (
                        100
                        if overall_total <= 0
                        else min(100, overall_sent * 100 // overall_total)
                    )
                    if percent >= next_percent or sent == file_size:
                        elapsed = max(time.monotonic() - started, 0.001)
                        rate = int(sent / elapsed)
                        message, progress_width = _progress_line(
                            label,
                            overall_sent,
                            overall_total,
                            rate,
                            progress_width,
                        )
                        sys.stderr.write(message)
                        sys.stderr.flush()
                        progress_rendered = True
                        next_percent = min(100, percent + 1)
        except (BrokenPipeError, ConnectionResetError):
            if progress_rendered:
                sys.stderr.write("\n")
                sys.stderr.flush()
            return

        if progress_rendered:
            sys.stderr.write("\n")
            sys.stderr.flush()

        if sent == file_size:
            _mark_file_complete(name)

    def do_HEAD(self) -> None:  # noqa: N802
        path = unquote(urlparse(self.path).path)
        name = path.rsplit("/", 1)[-1]
        if name not in ALLOWED_NAMES:
            self.send_error(404, "Not found")
            return
        file_path = self.serve_dir / name
        if not file_path.is_file():
            self.send_error(404, "Not found")
            return
        size = file_path.stat().st_size
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(size))
        self.send_header("Accept-Ranges", "none")
        self.end_headers()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bind",
        required=True,
        help="IPv4 address the device can reach (e.g. 192.168.55.2)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=0,
        help="TCP port (0 = ephemeral)",
    )
    parser.add_argument(
        "--dir",
        type=Path,
        required=True,
        help="Directory containing ota-package.tar.gz and .sig",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=1024 * 1024,
        help="read/write chunk size in bytes (default 1MiB)",
    )
    args = parser.parse_args()

    serve_dir = args.dir.resolve()
    if not serve_dir.is_dir():
        print(f"ERROR: not a directory: {serve_dir}", file=sys.stderr)
        return 2

    archive = serve_dir / "ota-package.tar.gz"
    sig = serve_dir / "ota-package.tar.gz.sig"
    if not archive.is_file() or not sig.is_file():
        print(
            "ERROR: serve dir must contain ota-package.tar.gz and .sig",
            file=sys.stderr,
        )
        return 2

    global _session_total
    _session_total = archive.stat().st_size + sig.stat().st_size

    OtaRequestHandler.serve_dir = serve_dir
    OtaRequestHandler.chunk_size = max(64 * 1024, args.chunk_size)

    try:
        server = ThreadingHTTPServer((args.bind, args.port), OtaRequestHandler)
    except OSError as exc:
        print(f"ERROR: bind {args.bind}:{args.port} failed: {exc}", file=sys.stderr)
        return 1

    host, port = server.server_address[:2]
    url_host = args.bind if args.bind not in ("0.0.0.0", "::") else str(host)
    base = f"http://{url_host}:{port}/"
    print(base, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    socket.setdefaulttimeout(None)
    raise SystemExit(main())
