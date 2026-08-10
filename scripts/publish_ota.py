#!/usr/bin/env python3
"""Publish HMI OTA tar.gz + .sig + channel manifest via R2 presigned PUT (lws-ui shape)."""
from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

USER_AGENT = "lws-hmi-publish/1.0"


def fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def format_bytes(value: int) -> str:
    units = ("B", "KiB", "MiB", "GiB")
    size = float(value)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} GiB"


def api_request_json(url: str, token: str) -> dict:
    req = urllib.request.Request(
        url,
        method="GET",
        headers={"Authorization": f"Bearer {token}", "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            body = "<failed to read error body>"
        fail(f"request failed: HTTP {e.code} {e.reason}; body: {body}")
    except Exception as e:
        fail(f"request failed: {e}")
    try:
        return json.loads(raw)
    except Exception:
        fail(f"invalid JSON response: {raw}")
    return {}


class _ProgressBody:
    """File-like body for urllib PUT with stderr progress (stream-file-progress style)."""

    def __init__(self, label: str, total: int, reader) -> None:
        self._label = label
        self._total = max(0, total)
        self._reader = reader
        self._sent = 0
        self._started = time.monotonic()
        self._next_percent = 0
        self._width = 0
        self._rendered = False

    def __len__(self) -> int:
        return self._total

    def read(self, size: int = -1) -> bytes:
        chunk = self._reader.read(size)
        if chunk:
            self._sent += len(chunk)
            self._report(final=self._sent >= self._total)
        elif self._total == 0 and not self._rendered:
            self._report(final=True)
        return chunk

    def _report(self, *, final: bool) -> None:
        total = self._total
        percent = 100 if total <= 0 else min(100, self._sent * 100 // total)
        if not final and percent < self._next_percent:
            return
        elapsed = max(time.monotonic() - self._started, 0.001)
        rate = int(self._sent / elapsed)
        message = (
            f"  {self._label}: {percent:3d}% "
            f"({format_bytes(self._sent)}/{format_bytes(total)}, "
            f"{format_bytes(rate)}/s)"
        )
        self._width = max(self._width, len(message))
        sys.stderr.write(f"\r{message:<{self._width}}")
        sys.stderr.flush()
        self._rendered = True
        self._next_percent = min(100, percent + 1)

    def close(self) -> None:
        if self._rendered:
            sys.stderr.write("\n")
            sys.stderr.flush()
        closer = getattr(self._reader, "close", None)
        if callable(closer):
            closer()


def upload_put(
    upload_url: str,
    content_type: str,
    *,
    path: str | None = None,
    payload: bytes | None = None,
    label: str,
) -> None:
    if path is not None:
        total = os.path.getsize(path)
        reader = open(path, "rb")
    elif payload is not None:
        total = len(payload)
        reader = io.BytesIO(payload)
    else:
        fail("upload_put: path or payload required")

    body = _ProgressBody(label, total, reader)
    req = urllib.request.Request(
        upload_url,
        data=body,
        method="PUT",
        headers={
            "Content-Type": content_type,
            "Content-Length": str(total),
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            _ = resp.read()
    except urllib.error.HTTPError as e:
        body.close()
        err_body = ""
        try:
            err_body = e.read().decode("utf-8", errors="replace")
        except Exception:
            err_body = "<failed to read error body>"
        fail(f"PUT upload failed: HTTP {e.code} {e.reason}; body: {err_body}")
    except Exception as e:
        body.close()
        fail(f"PUT upload failed: {e}")
    else:
        body.close()


def request_presigned(base_url: str, token: str, content_type: str, key: str) -> dict:
    query = urllib.parse.urlencode({"content_type": content_type, "key": key})
    url = f"{base_url}/v1/storage/r2/presigned-url?{query}"
    result = api_request_json(url, token)
    if result.get("success") is not True or result.get("code") != 200:
        fail(result.get("message") or "presigned request failed")
    data = result.get("data") or {}
    upload_url = data.get("upload_url")
    public_url = data.get("public_url")
    if not upload_url or not public_url:
        fail(f"presigned data missing upload_url/public_url: {data}")
    return {"upload_url": upload_url, "public_url": public_url}


def iso_now_utc() -> str:
    return (
        dt.datetime.now(dt.timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Publish OTA tar.gz + .sig + channel manifest via presigned R2 PUT"
    )
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--artifact", required=True, help="R2 prefix, e.g. lws-hmi")
    parser.add_argument("--archive-path", required=True)
    parser.add_argument("--sig-path", required=True)
    parser.add_argument("--pack-name", required=True, help="Remote basename, e.g. v1.0.38.tar.gz")
    parser.add_argument("--pack-version", required=True, help="Channel version without leading v, e.g. 1.0.38")
    parser.add_argument(
        "--manifest-name",
        required=True,
        choices=("release.json",),
        help="Channel manifest filename (release-only; staging.json removed)",
    )
    parser.add_argument(
        "--content-type",
        default="application/gzip",
        help="Content-Type for the package object (default application/gzip)",
    )
    parser.add_argument(
        "--version-prefix",
        default="v",
        help="Prefix for manifest version field (default 'v'; empty for control-board SW integers)",
    )
    args = parser.parse_args()

    archive_path = args.archive_path
    sig_path = args.sig_path
    if not os.path.isfile(archive_path):
        fail(f"archive not found: {archive_path}")
    if not os.path.isfile(sig_path):
        fail(f"signature not found: {sig_path} (need OTA_SIGNING_KEY / REQUIRE_OTA_SIG=1 make pack-ota)")

    base = args.base_url.rstrip("/")
    artifact = args.artifact.strip().strip("/")
    if not artifact:
        fail("artifact is empty")

    pack_name = args.pack_name
    archive_key = f"{artifact}/{pack_name}"
    sig_key = f"{artifact}/{pack_name}.sig"
    manifest_key = f"{artifact}/{args.manifest_name}"

    print(f"Requesting presigned URL for archive: {archive_key}", flush=True)
    archive_ps = request_presigned(base, args.token, args.content_type, archive_key)
    print(f"Uploading archive ({format_bytes(os.path.getsize(archive_path))})...", flush=True)
    upload_put(
        archive_ps["upload_url"],
        args.content_type,
        path=archive_path,
        label=pack_name,
    )

    print(f"Requesting presigned URL for signature: {sig_key}", flush=True)
    sig_ps = request_presigned(base, args.token, "application/octet-stream", sig_key)
    print(f"Uploading signature ({format_bytes(os.path.getsize(sig_path))})...", flush=True)
    upload_put(
        sig_ps["upload_url"],
        "application/octet-stream",
        path=sig_path,
        label=f"{pack_name}.sig",
    )

    # No sha512: device trust is Ed25519 .sig (cyber_ota defaults sig URL to package_url + ".sig").
    # System OTA / camera use prefix "v"; control-board SW integers use --version-prefix '' → "1017".
    manifest_version = f"{args.version_prefix}{args.pack_version}"
    manifest = {
        "version": manifest_version,
        "filename": pack_name,
        "published_at": iso_now_utc(),
        "url": archive_ps["public_url"],
    }
    manifest_bytes = json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"

    print(f"Requesting presigned URL for manifest: {manifest_key}", flush=True)
    manifest_ps = request_presigned(base, args.token, "application/json", manifest_key)
    print("Uploading manifest JSON...", flush=True)
    upload_put(
        manifest_ps["upload_url"],
        "application/json",
        payload=manifest_bytes,
        label=args.manifest_name,
    )

    print(f"artifact_url: {archive_ps['public_url']}")
    print(f"sig_url: {sig_ps['public_url']}")
    print(f"manifest_url: {manifest_ps['public_url']}")


if __name__ == "__main__":
    main()
