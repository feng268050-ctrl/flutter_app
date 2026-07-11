# Kernel boot log — EVB DTS deferred fixes (ynh960)

Base device tree is **Rockchip RK3566 EVB2** (`rk3566-evb2-lp4x-v10.dtsi` → `rk3566-evb.dtsi` → `rk3568-evb.dtsi`) plus Innohi `customer_board_ynh960.dtsi` and lws-hmi overlays.

**Machine model** in dmesg still reads `Rockchip RK3566 EVB2 LP4X V10 Board` — expected until a dedicated ynh960 `.dts` is forked (cosmetic only).

**P1 trim (applied):** [`overlay/kernel/rockchip/lws-hmi-ynh960-evb-trim.dtsi`](../overlay/kernel/rockchip/lws-hmi-ynh960-evb-trim.dtsi) disables EVB nodes with **no hardware** on ynh960:

| Node | Boot log (before trim) |
|------|------------------------|
| `tcs4525` / `tcs4526` / `syr837` / `syr838` / `xz3215` on `i2c0` | `fan53555-regulator … Failed to get chip ID!` |
| `&sfc` / `flash@0` (spi-nand) | `spi-nand spi4.0: unknown raw ID 00000000` |

After rebuild + flash, those two groups should disappear from early dmesg.

**Not trimmed:** `fiq-debugger` — bootargs use `console=ttyFIQ0`. Disabling the node stops **serial output after ~2 s** (earlycon ends) while the system **continues booting** (HMI OK, no userspace failure). Probe errors (`IRQ fiq not found`) are harmless noise; keep the node enabled for engineering serial.

---

## Deferred issues (track by product phase)

Use this table when a feature lands and dmesg warnings become symptoms. **Symptom** = what to check on device; **Fix direction** = typical DT/kernel work (confirm against Innohi schematic).

| Boot log / symptom | Likely cause | Phase | Impact today (P1) | Fix direction |
|--------------------|--------------|-------|-------------------|---------------|
| `arm-scmi … protocol 17/22 not active` | TF-A does not expose optional SCMI protocols | — | None; CRU/PMIC path still works | Ignore unless using SCMI-based idle/DVFS |
| `rockchip-vop2 … no regulator (vop)` | EVB OPP expects named `vop` rail; ynh960 uses RK817 | P1 polish / P3 | Display works; VOP OPP/dynamic voltage scaling missing | Add `&vop { vop-supply = <&vdd_logic>; };` (see `rk3566-rk817-tablet.dts`) |
| `dw-mipi-dsi … failed to find panel: -517` | `EPROBE_DEFER` during early probe | P1 | Normal if panel lights after ParamUpdate | If panel stays black: check `lws-hmi-ynh960-display.dtsi`, `960_lcd_param_rk356x.txt`, ParamUpdate |
| `Failed to initialize dvfs info cpu0` | No valid `vdd_cpu` regulator after EVB bucks removed; `&cpu0` only has `reg-name` | P2/P3 | CPU runs but fine-grained cpufreq/DVFS may be degraded | Map `&cpu0 { cpu-supply = <&…>; }` to actual CPU buck on ynh960 (schematic / Innohi); may be RK817 DCDC or external buck |
| `rockchip,bus bus-npu … no regulator (pvtm)` / `failed to get OPP table` | NPU bus OPP / leakage tables tied to EVB PMIC naming | **P3** (RKNPU) | NPU DVFS incomplete | Align NPU `pvtm-supply` / OPP with RK817 (`vdd_npu` exists on rk809); reference `rk3566-rk817-tablet.dts` |
| `RKNPU … can't request region` / `IRQ npu_irq not found` | RKNPU MMIO/IRQ node mismatch or conflict with EVB fragment | **P3** | RKNN runtime may fail probe | Verify `&rknpu` status, memory region, interrupts in board DTS; enable `lws_hmi_npu.config`; compare working RK3566 RKNPU dtsi |
| `mpp_rkvenc … Failed to get leakage` | Encoder OPP/leakage from EVB tables | **P5** (RTSP/record) | HW encode may be limited | Innohi/MPP dtsi for ynh960; enable when mediamtx path needs encode |
| `mpp_rkvdec2 … shared_niu_a/h is not found` | Missing NIU reset lines in DT for rkvdec2 | **P5** | HW decode may fail | Add reset/clock resources per Rockchip MPP binding for ynh960 |
| `rockchip-dmc … failed to get vop pn to msch rl` | DMC ↔ VOP bandwidth coupling (follows VOP regulator) | P2/P5 | DMC fixed freq still works | Fix `vop-supply` first; then revisit DMC devfreq if bandwidth tuning needed |
| `mdio_bus stmmac-1: MDIO device at address 0 is missing` | PHY not at MDIO addr 0 on ynh960 | **P2** (eth0 / IPC) | eth0 may not link if PHY addr wrong | Schematic → fix `&gmac1` PHY `reg`, reset GPIO, `tx_delay`/`rx_delay` |
| `own-gpio … pin gpio4-0 already requested by fe010000.ethernet` | `own-gpio` vs `stmmac` pinmux conflict on GPIO4_A0 | P2 / Innohi GPIO | `own-gpio` driver fails; vendor GPIO API may break | Schematic: drop unused node or remux; coordinate with Innohi `customer_board_ynh960.dtsi` |
| `fiq_debugger … IRQ fiq/wakeup not found` | EVB FIQ wiring absent; partial probe on ynh960 | — | Harmless; **keep node enabled** (`console=ttyFIQ0`) | Do not disable in evb-trim — serial goes quiet after ~2 s earlycon if disabled |
| `systemd[1]: Failed to find module 'autofs4'` | Kernel built without `CONFIG_AUTOFS_FS` | P5 / optional | Harmless warning at boot | Enable autofs in kernel **or** mask systemd unit that pulls it in |
| `Machine model: … EVB2 …` | Product still uses EVB2 `.dts` skeleton | P5 polish | None | Optional: fork `rk3566-ynh960.dts` with correct `model` / `compatible` |

---

## Verification after evb-trim rebuild

On serial console (USB unplugged for accurate port-22 KPI):

```bash
# Should be gone:
dmesg | grep -E 'fan53555|spi-nand'

# Still OK (until deferred row fixed):
dmesg | grep -E 'fiq_debugger|vop2|dvfs info cpu0|RKNPU|own-gpio|stmmac-1'

/usr/lib/lws-hmi/boot-verify.sh
```

---

## Related repo paths

| Path | Role |
|------|------|
| `overlay/kernel/rockchip/lws-hmi-ynh960-evb-trim.dtsi` | P1 EVB node disable |
| `overlay/kernel/rockchip/lws-hmi-ynh960-display.dtsi` | MIPI dsi0 + 800×1280 timing |
| `overlay/kernel/rockchip/lws-hmi-ynh960-linux-root.dtsi` | `root=/dev/mmcblk0p6` |
| `overlay/kernel/rockchip/lws-hmi-kernel-trim.config` | Kconfig driver trim (CAN/PCIe/CSI/…) |
| `board/960_lcd_param_rk356x.txt` | ParamUpdate MIPI params |
| `docs/boot-kpi-optimization.md` | Boot KPI / kernel trim A-3 |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-07-11 | Initial tracker; `lws-hmi-ynh960-evb-trim.dtsi` for FAN53555/SFC (not fiq-debugger — breaks serial after earlycon) |
