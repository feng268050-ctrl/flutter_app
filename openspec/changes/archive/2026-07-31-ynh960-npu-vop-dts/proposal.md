## Why

P3.3 AI/NPU smoke already runs RKNN inference on ynh960, but boot still logs EVB→product DTS gaps for NPU bus OPP (`pvtm-supply`), VOP OPP (`vop-supply`), and RKNPU named IRQ (`npu_irq`). Those rows were deferred in `docs/kernel-evb-dts-deferred.md` at P3; leaving them now risks incomplete NPU bus DVFS, missing VOP voltage scaling, and recurring probe noise that masks real regressions.

## What Changes

- Add a ynh960 kernel DTSI overlay that wires:
  - `&bus_npu` `pvtm-supply` to the product CPU buck (`&vdd_cpu_1`)
  - `&vop` `vop-supply` to `&vdd_logic` (RK817/rk809 rail already present)
  - `&rknpu` `interrupt-names = "npu_irq"` so the 6.1 driver by-name path succeeds without fallback error
- Hook the overlay through `scripts/apply-overlay.sh` (and restore/clean paths)
- Update `docs/kernel-evb-dts-deferred.md` to mark these rows fixed and correct the earlier “align to `vdd_npu`” note for bus-npu
- Document that `can't request region` under IOMMU mode is accepted driver noise (ioremap fallback), not a DT defect

## Capabilities

### New Capabilities

- `ynh960-npu-vop-dts`: Product DT supply/IRQ wiring for NPU bus OPP, VOP OPP, and RKNPU named IRQ on ynh960 EVB-derived trees

### Modified Capabilities

- (none — kernel overlay/docs only; no existing OpenSpec requirement text changes)

## Impact

- `overlay/kernel/rockchip/ynh960-npu-vop.dtsi` (new)
- `scripts/apply-overlay.sh` (sync + restore lists)
- `docs/kernel-evb-dts-deferred.md`, related paths in AGENTS/README only if rebuild guidance needs a note
- Board: `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` → `make build-kernel` → `make build-rootfs` → `make upgrade`
- Runtime verify: dmesg for `bus-npu` / `vop` / `npu_irq`; `bus-npu` and VOP OPP init; `make smoke-ai` regression
