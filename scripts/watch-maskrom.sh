#!/usr/bin/env bash
# Poll Mac USB + upgrade_tool while you try MaskROM (Recovery LED may stay off — that's OK).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPGRADE="$ROOT/tools/upgrade_tool/upgrade_tool"
SEC="${WATCH_SEC:-300}"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "watch-maskrom: macOS only (on Linux run: upgrade_tool ld in a loop)" >&2
  exit 1
fi

[[ -x "$UPGRADE" ]] || { echo "missing $UPGRADE" >&2; exit 1; }

cat <<'EOF'

=== MaskROM 监控（Recovery 灯不亮也继续试）===

重要：
  • Recovery 指示灯 = 软件控制的，U-Boot 坏了可能永远不亮
  • MaskROM = 芯片 ROM，与 eMMC 内容无关；只要 USB OTG + 按键/供电正确，Mac 应能看到 0x2207 设备
  • 工业 HMI 通常需要 **外部 DC 电源（12V/24V）**，仅 USB 供电可能不够

ynh960 建议顺序（每种多试 2–3 次）：

  A) 外部电源已接 + USB 数据线接 **烧录用 OTG 口**（不是面板 U 盘口）
     1. 断电（拔 DC + 拔 USB）
     2. 按住 Recovery 不松
     3. 上 DC 电源
     4. 插 USB 到 Mac（经有源 Hub）
     5. 继续按 5–10 秒再松开

  B) 若有 Reset 小键：按住 Recovery → 短按 Reset → 松 Reset → 再按 2 秒 → 松 Recovery

  C) 先插 USB 再按 Recovery 上电（部分板子时序相反）

  D) 换线 / 换 Hub / 换 Mac 口；禁用 USB 3 扩展坞，用 USB2 Hub

下面每 2 秒刷新。看到 Maskrom 或 Loader 立刻另开终端：
  make flash-android

EOF

echo "Monitoring ${SEC}s ..."
echo ""

for ((t = 0; t < SEC; t += 2)); do
  ts="$(date '+%H:%M:%S')"
  rock=""
  rock="$(cd "$ROOT/tools/upgrade_tool" && "$UPGRADE" ld 2>&1 | grep -v '^Using ' || true)"
  ioreg=""
  ioreg="$(ioreg -p IOUSB -l 2>/dev/null | grep -E 'idVendor|idProduct|USB Product Name|USB Vendor Name|@' \
    | grep -B2 -A2 '0x2207\|8720\|Rockchip\|Maskrom\|Loader' || true)"

  if grep -qiE 'Maskrom|Loader|DevNo=' <<<"$rock"; then
    echo "[$ts] *** RockUSB 已连接 ***"
    echo "$rock"
    echo ""
    echo "成功！另开终端执行: make flash-android"
    exit 0
  fi

  if [[ -n "$ioreg" ]]; then
    echo "[$ts] ioreg 发现 Rockchip USB:"
    echo "$ioreg" | head -20
    echo ""
    echo "尝试: make flash-android"
    exit 0
  fi

  printf '\r[%s] 等待 RockUSB ... %ds / %ds  (Recovery 灯灭是正常的)' "$ts" "$t" "$SEC"
  sleep 2
done

echo ""
echo ""
cat <<'EOF'

超时 — Mac 仍未看到 RockUSB。下一步：

1. 确认烧录 USB 口
   向 Innohi 确认 ynh960 哪一个是 OTG/Device 口（很多 HMI 烧录口在核心板，不是前面板 USB）。

2. 确认外部 DC 电源
   只插 USB 可能无法进入 MaskROM；接上规格书要求的 DC 再试 A/B 步骤。

3. 换 Windows + RKDevTool
   有时比 macOS upgrade_tool 更容易识别 MaskROM（需 Rockchip USB 驱动）。

4. 硬件强制 MaskROM（需拆机 + 经验）
   RK3568 通用做法：上电瞬间将 eMMC 的 D0(DATA0) 短接到 GND，同时 USB 接 PC。
   ⚠ 接错脚会损坏板子 — 必须有 ynh960 原理图或找 Innohi/板厂操作。

5. 串口 UART2（1500000, ttyFIQ0）
   即使 USB 救不了，串口仍可能看到 ROM/Loader 打印，便于判断是死机还是 USB 口/供电问题。

EOF
exit 1
