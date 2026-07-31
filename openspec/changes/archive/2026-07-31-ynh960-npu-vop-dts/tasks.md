## 1. Overlay DTSI

- [x] 1.1 Add `overlay/kernel/rockchip/ynh960-npu-vop.dtsi` with `&bus_npu` (`bus-supply` + `pvtm-supply`), `&vop` (`vop-supply`), and `&rknpu` (`interrupt-names = "npu_irq"`)
- [x] 1.2 Wire the DTSI into `scripts/apply-overlay.sh` sync + restore/clean lists

## 2. Docs

- [x] 2.1 Update `docs/kernel-evb-dts-deferred.md` (fixed rows, related paths, changelog; correct bus-npu fix direction away from `vdd_npu`)
- [x] 2.2 Note IOMMU `can't request region` as accepted if still listed

## 3. Verify notes

- [x] 3.1 Record board verify commands (dmesg / sysfs / `make smoke-ai`) and rebuild sequence for the user
