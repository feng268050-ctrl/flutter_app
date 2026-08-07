#!/usr/bin/env python3
"""Resolve Buildroot 2024.02→2025.02.16 3-way merge conflicts for lws-hmi.

Policy (design D3):
- Prefer upstream LTS for generic packages/infra.
- Preserve Rockchip vendor trees (board/rockchip, package/rockchip).
- Product overlay packages (OpenSSL/GST/BlueZ/Flutter) are re-injected by
  apply-overlay; take upstream base when both sides touched the recipe.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

WORK = Path(sys.argv[1] if len(sys.argv) > 1 else ".")


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=WORK, check=check, text=True, capture_output=True)


def status_short() -> list[tuple[str, str]]:
    out = run(["git", "status", "--porcelain"]).stdout
    rows = []
    for line in out.splitlines():
        if not line:
            continue
        # XY PATH or XY ORIG -> PATH
        xy = line[:2]
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        rows.append((xy, path))
    return rows


def checkout(side: str, paths: list[str]) -> None:
    if not paths:
        return
    # git checkout --ours/--theirs then add
    for i in range(0, len(paths), 50):
        chunk = paths[i : i + 50]
        run(["git", "checkout", f"--{side}", "--", *chunk], check=False)
        run(["git", "add", "--", *chunk], check=False)


def rm_paths(paths: list[str]) -> None:
    if not paths:
        return
    for i in range(0, len(paths), 50):
        chunk = paths[i : i + 50]
        run(["git", "rm", "-f", "--", *chunk], check=False)


def add_paths(paths: list[str]) -> None:
    if not paths:
        return
    for i in range(0, len(paths), 50):
        chunk = paths[i : i + 50]
        run(["git", "add", "--", *chunk], check=False)


def prefer_vendor(path: str) -> bool:
    if path.startswith("board/rockchip/") or path == "board/rockchip":
        return True
    if path.startswith("package/rockchip/") or path == "package/rockchip":
        return True
    if path.startswith("package/rockchip/"):
        return True
    # Product overlay stash dirs and local markers
    if "/.lws-" in path or path.startswith("archives/") or path == "README.rockchip":
        return True
    if path.startswith("scripts/") and not path.startswith("support/scripts/"):
        # Rockchip top-level scripts/ (env helpers), not BR support/scripts
        return True
    if path in {"envsetup.sh", "README.rockchip"}:
        return True
    return False


def main() -> int:
    rows = status_short()
    ours: list[str] = []
    theirs: list[str] = []
    delete: list[str] = []
    add_theirs: list[str] = []
    add_ours: list[str] = []

    for xy, path in rows:
        x, y = xy[0], xy[1]
        # Unmerged codes: DD, AU, UD, UA, DU, AA, UU
        if xy not in {"DD", "AU", "UD", "UA", "DU", "AA", "UU"} and "U" not in xy:
            continue

        if prefer_vendor(path):
            if xy == "DD":
                delete.append(path)
            elif xy in {"UD", "DU"} and x == "D":
                # deleted by us — keep deleted if vendor deleted; else restore ours
                delete.append(path)
            else:
                ours.append(path)
            continue

        # Generic / upstream preference
        if xy == "DD":
            delete.append(path)
        elif xy == "UD":
            # deleted by us, modified by them → take upstream (restore theirs)
            theirs.append(path)
        elif xy == "DU":
            # deleted by them, modified by us → take upstream delete
            delete.append(path)
        elif xy == "AU":
            # added by us, modified? unmerged add by us — for gcc patches take theirs layout
            # AU = added by us, updated by them in index? In merge: added by us
            # Prefer upstream presence: if theirs exists use theirs else ours
            theirs.append(path)
        elif xy == "UA":
            # added by them
            theirs.append(path)
        elif xy == "AA":
            # both added — prefer upstream recipe; overlay re-injects product pins
            theirs.append(path)
        elif xy == "UU":
            theirs.append(path)
        else:
            theirs.append(path)

    print(f"resolve: ours={len(ours)} theirs={len(theirs)} delete={len(delete)}")
    checkout("ours", ours)
    checkout("theirs", theirs)
    rm_paths(delete)

    # Critical Config.in: start from upstream, re-inject vendor rockchip mega-tree source
    fix_package_config_in()
    fix_top_config_in()

    # Remaining unmerged?
    left = run(["git", "diff", "--name-only", "--diff-filter=U"], check=False).stdout.strip()
    if left:
        print("REMAINING CONFLICTS:")
        print(left)
        return 1
    # Conflict markers left in tracked files?
    markers = run(
        ["git", "grep", "-l", r"^<<<<<<< ", "--", "."],
        check=False,
    ).stdout.strip()
    if markers:
        print("REMAINING CONFLICT MARKERS:")
        print(markers)
        return 1
    print("resolve: all unmerged paths cleared")
    return 0


def stage_blob(path: str, side: str) -> None:
    """side: ours=2 theirs=3"""
    stage = "2" if side == "ours" else "3"
    blob = run(["git", "show", f":{stage}:{path}"], check=False)
    if blob.returncode != 0:
        return
    Path(WORK / path).write_bytes(blob.stdout.encode() if isinstance(blob.stdout, str) else blob.stdout)
    # git show returns text=True so string — rewrite properly
    raw = run(["git", "show", f":{stage}:{path}"], check=False)
    # Re-run without text for binary safety
    raw = subprocess.run(
        ["git", "show", f":{stage}:{path}"],
        cwd=WORK,
        check=False,
        capture_output=True,
    )
    if raw.returncode != 0:
        return
    p = WORK / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(raw.stdout)
    run(["git", "add", "--", path])


def show_ref(ref_path: str) -> bytes:
    """Show blob from merge stage (:2/:3) or branch ref (vendor:/upstream:)."""
    for spec in (ref_path,):
        raw = subprocess.run(
            ["git", "show", spec], cwd=WORK, capture_output=True
        )
        if raw.returncode == 0:
            return raw.stdout
    return b""


def fix_package_config_in() -> None:
    """Take upstream package/Config.in and ensure vendor package/rockchip is sourced."""
    raw = show_ref(":3:package/Config.in") or show_ref("upstream:package/Config.in")
    vendor = show_ref(":2:package/Config.in") or show_ref("vendor:package/Config.in")
    if not raw:
        raise SystemExit("cannot load upstream package/Config.in")
    text = raw.decode()
    body = text
    if 'source "package/rockchip/Config.in"' not in body:
        # Insert before rockchip-rkbin (upstream) or after menu Target packages
        rkbin = '\tsource "package/rockchip-rkbin/Config.in"\n'
        inject = '\tsource "package/rockchip/Config.in"\n'
        if rkbin in body:
            body = body.replace(rkbin, inject + rkbin, 1)
        else:
            needle = 'menu "Target packages"\n'
            if needle in body:
                body = body.replace(needle, needle + inject, 1)
            else:
                body = inject + body
    # Preserve any other vendor-only source lines (besides rockchip mega-tree)
    if vendor:
        vtext = vendor.decode()
        for line in vtext.splitlines():
            s = line.strip()
            if (
                s.startswith("source ")
                and s not in body
                and "rockchip" in s
                and "rockchip-mali" not in s
                and "rockchip-rkbin" not in s
            ):
                # already handled package/rockchip
                if 'package/rockchip/Config.in' in s:
                    continue
                body = body.rstrip() + "\n" + line + "\n"
    p = WORK / "package/Config.in"
    p.write_text(body)
    run(["git", "add", "--", "package/Config.in"])
    print("fix: package/Config.in (upstream + source package/rockchip)")


def fix_top_config_in() -> None:
    """Top-level Config.in: prefer upstream; vendor rarely needs top-level hooks."""
    ours = show_ref(":2:Config.in") or show_ref("vendor:Config.in")
    theirs = show_ref(":3:Config.in") or show_ref("upstream:Config.in")
    if not theirs:
        return
    o = ours.decode() if ours else ""
    t = theirs.decode()
    extra = []
    for line in o.splitlines():
        s = line.strip()
        if s.startswith("source ") and s not in t and "rockchip" in s.lower():
            extra.append(line)
    body = t
    if extra:
        body = t.rstrip() + "\n" + "\n".join(extra) + "\n"
        print(f"fix: Config.in added {len(extra)} vendor source lines")
    else:
        print("fix: Config.in took upstream")
    (WORK / "Config.in").write_text(body)
    run(["git", "add", "--", "Config.in"])


if __name__ == "__main__":
    sys.exit(main())
