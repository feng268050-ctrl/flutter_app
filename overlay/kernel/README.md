# Kernel overlay (platform)

**Board device trees:** git source of truth is [`rockchip/`](rockchip/) (`ynh960.dts`,
`customer_board_*.dtsi`, …). **Drivers:** AIC8800 combo under
[`drivers/net/wireless/aic8800/`](drivers/net/wireless/aic8800/); leftover
board helpers under [`innohi/`](innohi/) (README only — `gpio_innohi` removed; product GPIO is gpiod).
`make apply-overlay` copies kernel trees into `linux-sdk/kernel/`.

Kernel **patches** and stable device script patches are squashed into owned
`linux-sdk/` by `make squash-linux-sdk-platform` / `make trim-linux-sdk` (W3).

**FIT inventory:** product `board_id` values that ship in the family boot FIT are
listed in [`board/rk356x-fit-boards.txt`](../../board/rk356x-fit-boards.txt)
(not discovered by globbing this directory). Add a board here **and** append that
`board_id` to the inventory; regenerate ITS via `scripts/generate-boot-fit-its.sh`
(or `make apply-overlay`). Emulator/`sim` is not a FIT conf.

**Policy:** kernel C patches → squash / owned tree. **DTS / `*.config` / firmware /
logo** → edit here and `make apply-overlay` every time.

Third-party Buildroot packages stay under `overlay/buildroot/package/` and
`overlay/third-party/`.
