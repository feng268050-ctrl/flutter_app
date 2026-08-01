# Kernel overlay (platform)

Stable board DTS / Kconfig fragments and patches under this tree are **squashed**
into the local owned `linux-sdk/` by `make squash-linux-sdk-platform` /
`make trim-linux-sdk` (W3).

**FIT inventory:** product `board_id` values that ship in the family boot FIT are
listed in [`board/rk356x-fit-boards.txt`](../../board/rk356x-fit-boards.txt)
(not discovered by globbing this directory). Add a board here **and** append that
`board_id` to the inventory; regenerate ITS via `scripts/generate-boot-fit-its.sh`
(or `make apply-overlay`). Emulator/`sim` is not a FIT conf.

**Policy:** delete-only for new platform work. Prefer editing the owned kernel
tree (or re-run squash after an intentional change here). Do not keep growing
this directory as a long-term patch queue.

Third-party Buildroot packages are **not** part of this squash — they stay under
`overlay/buildroot/package/` and `overlay/third-party/`.
