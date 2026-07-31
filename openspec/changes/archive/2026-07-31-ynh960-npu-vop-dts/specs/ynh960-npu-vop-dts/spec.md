## ADDED Requirements

### Requirement: ynh960 NPU bus PVTM supply

The ynh960 product device tree overlay SHALL set `&bus_npu` `pvtm-supply` to the product CPU buck phandle `&vdd_cpu_1` (regulator-name `vdd_cpu`) so Rockchip bus OPP init can resolve the `pvtm` regulator consumer. The overlay MUST keep `bus-supply` pointed at `&vdd_logic` when present. The repository SoT for this wiring SHALL live under `overlay/kernel/rockchip/` and be applied via `scripts/apply-overlay.sh`.

#### Scenario: bus-npu OPP initializes without pvtm regulator error

- **WHEN** the board boots a kernel built with the ynh960 NPU/VOP overlay applied
- **THEN** dmesg SHALL NOT contain `bus-npu` `_opp_set_regulators: no regulator (pvtm) found`
- **AND** `/proc/device-tree/bus-npu/pvtm-supply` SHALL exist

#### Scenario: bus-npu power control path is available

- **WHEN** `bus-npu` OPP init succeeds after the overlay is applied
- **THEN** the platform device SHALL expose a working OPP/power-control path (no `failed to get OPP table` / `failed to init power control` for `bus-npu`)

### Requirement: ynh960 VOP supply for OPP

The ynh960 product device tree overlay SHALL set `&vop` `vop-supply` to `&vdd_logic` so VOP OPP regulator binding matches RK817-class boards.

#### Scenario: VOP probe finds vop regulator

- **WHEN** the board boots a kernel built with the ynh960 NPU/VOP overlay applied
- **THEN** dmesg SHALL NOT contain `rockchip-vop2` `_opp_set_regulators: no regulator (vop) found`
- **AND** `/proc/device-tree` for the VOP node SHALL expose `vop-supply`

### Requirement: ynh960 RKNPU named IRQ

The ynh960 product device tree overlay SHALL set `&rknpu` `interrupt-names = "npu_irq"` for the existing SoC interrupt so the RKNPU driver can resolve the IRQ by name on Linux 6.1.

#### Scenario: RKNPU IRQ resolves by name

- **WHEN** the board boots a kernel built with the ynh960 NPU/VOP overlay applied
- **THEN** dmesg SHALL NOT report `IRQ npu_irq not found` for `fde40000.npu`
- **AND** the RKNPU device SHALL remain bound and usable for RKNN inference

### Requirement: Deferred tracker documents closure

`docs/kernel-evb-dts-deferred.md` SHALL mark the bus-npu pvtm/OPP and VOP `vop-supply` rows (and the RKNPU `npu_irq` naming aspect) as fixed for this change, and SHALL note that IOMMU-mode `can't request region` remains accepted noise unless a driver change lands later.

#### Scenario: Tracker matches shipped DT

- **WHEN** a reader checks the deferred table after this change ships
- **THEN** those P3 NPU/VOP/IRQ rows are marked fixed with a pointer to the overlay path
