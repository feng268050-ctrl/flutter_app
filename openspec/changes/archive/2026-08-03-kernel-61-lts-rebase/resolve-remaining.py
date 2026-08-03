#!/usr/bin/env python3
"""Resolve remaining kernel 6.1.99→6.1.180 merge conflicts in the work repo."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(
    "/Users/ayon/Workspace/lws-hmi/linux-sdk/.lws-kernel-lts-merge/repo"
)


def replace_hunks(path: Path, resolvers: list) -> None:
    text = path.read_text(errors="replace")
    hunks = list(
        re.finditer(
            r"^<<<<<<<[^\n]*\n(.*?)^=======\n(.*?)^>>>>>>>[^\n]*\n",
            text,
            flags=re.M | re.S,
        )
    )
    if len(hunks) != len(resolvers):
        raise SystemExit(
            f"{path}: expected {len(resolvers)} hunks, found {len(hunks)}"
        )
    out: list[str] = []
    last = 0
    for h, fn in zip(hunks, resolvers):
        out.append(text[last : h.start()])
        out.append(fn(h.group(1), h.group(2)))
        last = h.end()
    out.append(text[last:])
    path.write_text("".join(out))
    print(f"resolved {path.relative_to(REPO)}")


def main() -> int:
    ours = lambda o, t: o  # noqa: E731
    theirs = lambda o, t: t  # noqa: E731

    def both(o: str, t: str) -> str:
        return o + t

    replace_hunks(
        REPO / "arch/arm64/boot/dts/rockchip/rk3568.dtsi",
        [theirs, theirs],
    )
    replace_hunks(
        REPO / "arch/arm64/boot/dts/rockchip/rk356x.dtsi",
        [both, theirs],
    )
    replace_hunks(REPO / "drivers/gpio/gpio-rockchip.c", [ours] * 5)
    replace_hunks(
        REPO / "drivers/gpu/drm/drm_gem.c",
        [
            lambda o, t: (
                "\tif (drm_WARN_ON(obj->dev, !data))\n"
                "\t\treturn 0;\n\n" + o
            )
        ],
    )
    replace_hunks(REPO / "drivers/mmc/host/sdhci-of-dwcmshc.c", [ours] * 5)
    replace_hunks(
        REPO / "drivers/net/ethernet/stmicro/stmmac/common.h",
        [
            lambda o, t: (
                "#endif\n"
                "#define STMMAC_GET_ENTRY(x, size)\t((x + 1) & (size - 1))\n"
                "#define STMMAC_NEXT_ENTRY(x, size)\tSTMMAC_GET_ENTRY(x, size)\n"
            )
        ],
    )
    replace_hunks(
        REPO / "drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c",
        [ours],
    )
    replace_hunks(
        REPO / "drivers/net/ethernet/stmicro/stmmac/stmmac_main.c",
        [theirs],
    )
    replace_hunks(
        REPO / "drivers/phy/rockchip/phy-rockchip-inno-usb2.c",
        [ours] * 7,
    )
    replace_hunks(
        REPO / "drivers/phy/rockchip/phy-rockchip-naneng-combphy.c",
        [lambda o, t: t + o],
    )
    replace_hunks(
        REPO / "drivers/phy/rockchip/phy-rockchip-usb.c",
        [lambda o, t: o + "#include <linux/property.h>\n"],
    )
    replace_hunks(REPO / "drivers/tee/optee/supp.c", [ours])
    replace_hunks(
        REPO / "drivers/tty/serial/8250/8250_dma.c",
        [
            lambda o, t: o.replace("#else\n\n", "")
            + "\n"
            + t
            + "\n#else\n\n"
        ],
    )
    replace_hunks(
        REPO / "drivers/tty/serial/8250/8250_dw.c",
        [
            lambda o, t: (
                '\t{ .compatible = "sophgo,sg2044-uart", '
                ".data = &dw8250_skip_set_rate_data },\n" + o
            )
        ],
    )
    replace_hunks(REPO / "drivers/usb/dwc2/hcd.c", [theirs])
    replace_hunks(
        REPO / "drivers/usb/dwc3/core.c",
        [lambda o, t: o + "\n" + t, lambda o, t: o + "\n" + t],
    )
    replace_hunks(REPO / "drivers/usb/dwc3/gadget.c", [theirs])
    replace_hunks(
        REPO / "drivers/usb/gadget/function/f_hid.c",
        [theirs, theirs],
    )

    left = subprocess.check_output(
        ["git", "diff", "--name-only", "--diff-filter=U"],
        cwd=REPO,
        text=True,
    ).strip()
    print("UNMERGED:", left or "none")

    check = [
        "arch/arm64/boot/dts/rockchip/rk3568.dtsi",
        "arch/arm64/boot/dts/rockchip/rk356x.dtsi",
        "drivers/gpio/gpio-rockchip.c",
        "drivers/gpu/drm/drm_gem.c",
        "drivers/mmc/host/sdhci-of-dwcmshc.c",
        "drivers/net/ethernet/stmicro/stmmac/common.h",
        "drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c",
        "drivers/net/ethernet/stmicro/stmmac/stmmac_main.c",
        "drivers/phy/rockchip/phy-rockchip-inno-usb2.c",
        "drivers/phy/rockchip/phy-rockchip-naneng-combphy.c",
        "drivers/phy/rockchip/phy-rockchip-usb.c",
        "drivers/tee/optee/supp.c",
        "drivers/tty/serial/8250/8250_dma.c",
        "drivers/tty/serial/8250/8250_dw.c",
        "drivers/usb/dwc2/hcd.c",
        "drivers/usb/dwc3/core.c",
        "drivers/usb/dwc3/gadget.c",
        "drivers/usb/gadget/function/f_hid.c",
    ]
    bad = [rel for rel in check if "<<<<<<<" in (REPO / rel).read_text(errors="replace")]
    print("markers left in:", bad or "none")
    return 1 if bad or left else 0


if __name__ == "__main__":
    sys.exit(main())
