# Host-side tools for IP-camera RTSP bitrate checks

Used by:

- `scripts/measure-ip-camera-rtsp.sh` (Mac / host)
- `scripts/measure-ip-camera-rtsp-adb.sh` (Android)
- `scripts/measure-ip-camera-rtsp-ssh.sh` (Linux HMI)

Acceptance criteria and pitfall log:
[`docs/ip-camera-rtsp-bitrate-android-vs-linux.md`](../docs/ip-camera-rtsp-bitrate-android-vs-linux.md).

## Cached binaries (not in git)

Place under repo `.cache/` (typically gitignored):

| Path | What |
|------|------|
| `.cache/ffmpeg-android/ffmpeg` | johnvansickle **linux-arm64** static `ffmpeg` — push to board `/tmp/ffmpeg` or Android `/data/local/tmp/ffmpeg` |
| `.cache/android-ethtool/ethtool-static` | static aarch64 `ethtool` — Android MMC counters (`mmc_rx_crc_error`) |

Override with `FFMPEG_HOST=` / copy ethtool manually when comparing Android vs Linux CRC.

## Quick Linux board check

```bash
SN=<product-sn> STREAMS="PR1 PR0" scripts/measure-ip-camera-rtsp-ssh.sh 12
```

Expect remux ≥ ~3.3 Mbps, `mmc_crc_delta≈0`, `rtp_missed≈0` with `STOP_SERVICES=1`.
