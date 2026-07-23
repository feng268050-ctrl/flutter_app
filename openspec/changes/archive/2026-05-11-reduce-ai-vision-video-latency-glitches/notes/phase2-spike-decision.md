# Phase-2 spike decision (reduce-ai-vision-video-latency-glitches)

**Decision date:** 2026-05-11

**Context:** Phase 1 stays on EasyDarwin `EasyPlayerClient` + documented tuning (low-latency prefs, recovery backoff, network diagnostics). JNI/EasyRTSP buffer knobs were audited in task 3.1; further gains without replacing the stack are incremental.

**Chosen direction for the next engineering spike (not in phase-1 scope):**

1. **Short POC — FFmpeg / ffplay TCP + low-latency flags** (`-fflags nobuffer`, `-flags low_delay`, small probesize where applicable) using the **same RTSP URL** as the app, to validate whether additional receive-side buffering exists above what Java exposes. Low effort; isolates “library vs network” if VLC and ffplay disagree with the app.

2. **MPP “direct” decode path** — reserve for a **product decision** to replace or bypass EasyDarwin for AI Vision. Requires ownership of surface pipeline + maintenance cost; do **not** start until ffplay/VLC vs App gap is measured and phase-1 mitigations are exhausted.

**Rationale:** Avoid parallel heavy native rewrites while phase-1 changes (network correctness, decode type=1, AI offload from decode callback, queue bounds) are still rolling out.
