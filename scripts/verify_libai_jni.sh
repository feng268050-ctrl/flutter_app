#!/usr/bin/env bash
# Verify libai.so exports typed stain infer JNI symbols required by lws-ui.
# Delegates to native/lensinspector/scripts/verify_libai_jni.sh (llvm-nm for arm64 .so).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/native/lensinspector/scripts/verify_libai_jni.sh" "$@"
