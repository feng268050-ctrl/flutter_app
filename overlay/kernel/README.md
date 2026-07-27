# Kernel overlay (platform)

Stable ynh960 DTS / Kconfig fragments and patches under this tree are **squashed**
into the local owned `linux-sdk/` by `make squash-linux-sdk-platform` /
`make trim-linux-sdk` (W3).

**Policy:** delete-only for new platform work. Prefer editing the owned kernel
tree (or re-run squash after an intentional change here). Do not keep growing
this directory as a long-term patch queue.

Third-party Buildroot packages are **not** part of this squash — they stay under
`overlay/buildroot/package/` and `overlay/third-party/`.
