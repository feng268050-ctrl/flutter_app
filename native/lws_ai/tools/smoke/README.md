# AI board smoke helpers

Host-driven NPU / daemon checks (not shipped in `/opt/hmi`).

| File | Role |
|------|------|
| `unix_json_req.c` | Tiny aarch64 client for `/run/hmi/ai/cmd.sock` JSON lines |
| `rknn_init_smoke.c` | Optional `rknn_init` on `/userdata/models/*.rknn` (needs `librknnrt`) |

Demo images (ROI-compatible pad for stain det):

- `../../assets/img/stain_demo.jpg` — original 1280×720
- `../../assets/img/stain_demo_1920x1080.jpg` — letterboxed 1920×1080 (use this for offline RKNN)

From repo root:

```text
make smoke-ai
```

Uploads images + `config.yaml` to `/var/lib/hmi/ai/`, then `ping` + `offline_infer_rknn_stain_jpg`.
