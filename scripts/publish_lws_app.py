#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request
import urllib.error

USER_AGENT = "curl/8.7.1"


def fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def api_request_json(url: str, token: str) -> dict:
    auth_value = f"Bearer {token}"
    req = urllib.request.Request(
        url,
        method="GET",
        headers={"Authorization": auth_value, "User-Agent": USER_AGENT},
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


def upload_put(upload_url: str, content_type: str, payload: bytes) -> None:
    req = urllib.request.Request(
        upload_url,
        data=payload,
        method="PUT",
        headers={"Content-Type": content_type, "User-Agent": USER_AGENT},
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            _ = resp.read()
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            body = "<failed to read error body>"
        fail(f"PUT upload failed: HTTP {e.code} {e.reason}; body: {body}")
    except Exception as e:
        fail(f"PUT upload failed: {e}")


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


def sha512_hex(path: str) -> str:
    h = hashlib.sha512()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def iso_now_utc() -> str:
    # Example: 2026-04-09T05:56:41.964Z
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish lws-app zip + manifest via presigned URL")
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--token", required=True)
    parser.add_argument("--zip-path", required=True)
    parser.add_argument("--pack-name", required=True)
    parser.add_argument("--pack-version", required=True)
    parser.add_argument("--manifest-name", required=True)
    parser.add_argument("--expected-public-base", required=False, default="")
    args = parser.parse_args()

    zip_path = args.zip_path
    if not os.path.isfile(zip_path):
        fail(f"zip not found: {zip_path}")

    artifact_key = f"lws-app/{args.pack_name}"
    manifest_key = f"lws-app/{args.manifest_name}"
    expected_base = args.expected_public_base.strip()

    print(f"Requesting presigned URL for artifact key: {artifact_key}", flush=True)
    artifact_ps = request_presigned(
        base_url=args.base_url.rstrip("/"),
        token=args.token,
        content_type="application/zip",
        key=artifact_key,
    )
    with open(zip_path, "rb") as f:
        zip_bytes = f.read()
    print("Uploading artifact zip...", flush=True)
    upload_put(artifact_ps["upload_url"], "application/zip", zip_bytes)

    manifest = {
        "version": f"v{args.pack_version}",
        "filename": args.pack_name,
        "published_at": iso_now_utc(),
        "sha512": sha512_hex(zip_path),
        "url": artifact_ps["public_url"],
    }
    manifest_bytes = json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8")

    print(f"Requesting presigned URL for manifest key: {manifest_key}", flush=True)
    manifest_ps = request_presigned(
        base_url=args.base_url.rstrip("/"),
        token=args.token,
        content_type="application/json",
        key=manifest_key,
    )
    print("Uploading manifest JSON...", flush=True)
    upload_put(manifest_ps["upload_url"], "application/json", manifest_bytes)

    if expected_base:
        if not artifact_ps["public_url"].startswith(expected_base):
            fail(
                f"artifact public_url prefix mismatch: got {artifact_ps['public_url']}, expected prefix {expected_base}"
            )
        if not manifest_ps["public_url"].startswith(expected_base):
            fail(
                f"manifest public_url prefix mismatch: got {manifest_ps['public_url']}, expected prefix {expected_base}"
            )

    print(f"artifact_url: {artifact_ps['public_url']}")
    print(f"manifest_url: {manifest_ps['public_url']}")


if __name__ == "__main__":
    main()
