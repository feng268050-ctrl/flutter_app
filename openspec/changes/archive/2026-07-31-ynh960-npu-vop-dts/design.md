## Context

ynh960 boots from Rockchip RK3566 EVB2 DTS (`rk3566-evb2-lp4x-v10` → `rk3568-evb.dtsi`) plus Innohi `customer_board_ynh960.dtsi` and lws-hmi overlays. P1 already fixed CPU DVFS via `ynh960-evb-trim.dtsi` (`&cpu0` → `&vdd_cpu_1`). P3.3 AI uses `fde40000.npu` successfully, but live dmesg still shows:

- `rockchip,bus bus-npu: … no regulator (pvtm) found` → OPP table init fails; no `bus-npu` devfreq
- `rockchip-vop2 … no regulator (vop) found` → VOP OPP incomplete
- `RKNPU … IRQ npu_irq not found` → 6.1 driver tries `platform_get_irq_byname` first; SoC node has `interrupts` but no `interrupt-names`

Device regulators `vdd_cpu`, `vdd_logic`, and `vdd_npu` are present. EVB already sets `bus-supply = <&vdd_logic>` and `rknpu-supply = <&vdd_npu>`, but comments out `pvtm-supply` and never sets `vop-supply`. Reference: `rk3566-rk817-tablet.dts`.

## Goals / Non-Goals

**Goals:**

- Enable NPU **bus** OPP/power control by supplying the PVTM regulator consumer
- Enable VOP OPP regulator wiring for dynamic voltage selection
- Name the RKNPU IRQ so by-name lookup succeeds (no `-ENXIO` error log)
- Keep the fix in git-owned `overlay/kernel/` and apply-overlay, matching other ynh960 DTSI slices
- Update the deferred tracker so P3 NPU/VOP rows are closed

**Non-Goals:**

- Forking a dedicated `rk3566-ynh960.dts` / changing Machine model string (P5 polish)
- Fixing `can't request region` for NPU MMIO under IOMMU (driver falls back to `devm_ioremap`; not a supply/IRQ DT bug)
- MPP rkvenc leakage / rkvdec NIU (still P5)
- Changing userspace AI daemon or RKNN runtime packaging
- CPU DVFS (already done in evb-trim)

## Decisions

1. **Single overlay `ynh960-npu-vop.dtsi`** — one file for bus-npu + vop + rknpu IRQ so apply-overlay has one hook and reviews stay scoped to P3.3 DVFS/IRQ. Alternative: fold VOP into `ynh960-display.dtsi` — rejected to keep display timing separate from power/IRQ.

2. **`pvtm-supply = <&vdd_cpu_1>`** — matches tablet’s `<&vdd_cpu>` role and the same xz3215 buck already used for `&cpu0`. Not `vdd_npu` (that rail is already `rknpu-supply`).

3. **`vop-supply = <&vdd_logic>`** — matches tablet and EVB’s existing `center-supply` / logic rail; no new PMIC nodes.

4. **`&rknpu { interrupt-names = "npu_irq"; }`** — SoC already has one SPI interrupt; naming matches `rknpu_irqs[]` in `rknpu_drv.c`. Do not change interrupt number or add a second IRQ.

5. **Leave IOMMU mem-region warning** — document as accepted when `iommu is enabled`; fixing would mean driver patch to skip `devm_ioremap_resource`, out of overlay scope.

## Risks / Trade-offs

- [Wrong PVTM rail] → Mitigation: use proven `&vdd_cpu_1`; verify after flash that `bus-npu` gets OPP and no new regulator errors
- [VOP voltage change affects panel stability] → Mitigation: same rail EVB/tablet use; smoke display after upgrade; rollback = remove overlay include
- [IRQ name typo breaks probe] → Mitigation: exact `npu_irq` string from driver; verify `/proc/interrupts` and no “no npu npu_irq in dts”
- [apply-overlay restore misses new file] → Mitigation: add to both sync rm lists and restore rm lists

## Migration Plan

1. Land overlay + apply-overlay + docs
2. On build host: `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade`
3. Verify dmesg / sysfs / `make smoke-ai`
4. Rollback: revert overlay commit and rebuild kernel, or temporarily drop the `#include` via restore path

## Open Questions

- None blocking; board schematic confirmation of xz3215 / RK809 rails already done in P1 trim work.
