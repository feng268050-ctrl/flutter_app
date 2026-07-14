# lws_hmi — flutter-pi HMI (embedded Linux)

This tree targets **ynh960 / flutter-pi** via `flutterpi_tool` (`make build-app`).
It is not a phone app: only the **`linux/`** platform stub is kept (plugin registrant /
FFI helpers). `android/` / `ios/` / `macos/` / `web/` / `windows/` are intentionally absent.

P2.5 can re-add a mobile target later, for example:

```bash
cd app/hmi
flutter create --platforms=android .
```

See [`../README.md`](../README.md) for engine pins and deploy layout.
