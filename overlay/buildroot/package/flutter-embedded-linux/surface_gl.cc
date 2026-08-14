// Copyright 2023 Sony Corporation. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// LWS: present-hook for libhmi_capture (screen capture) before eglSwapBuffers.
// Kept as C++ to match flutter-wayland-client / SurfaceGl (not a C translation unit).

#include "flutter/shell/platform/linux_embedded/surface/surface_gl.h"

#include <dlfcn.h>

#include <atomic>
#include <cstdint>

namespace flutter {
namespace {

using HmiCapturePresentFn = void (*)(void *(*)(const char *), int, int);
using GlGetIntegervFn = void (*)(unsigned int, int *);

constexpr unsigned int kGlViewport = 0x0BA2;

void *SurfaceGlGetProcThunk(const char *name);

struct CaptureHookState {
  std::atomic<bool> tried{false};
  HmiCapturePresentFn present_fn = nullptr;
  void *lib = nullptr;
  const SurfaceGl *surface = nullptr;
};

CaptureHookState &HookState() {
  static CaptureHookState state;
  return state;
}

void *SurfaceGlGetProcThunk(const char *name) {
  const SurfaceGl *surface = HookState().surface;
  if (!surface || !name) {
    return nullptr;
  }
  return surface->GlProcResolver(name);
}

void MaybeHmiCapturePresent(const SurfaceGl *self) {
  CaptureHookState &st = HookState();
  if (!st.tried.exchange(true)) {
    st.lib = dlopen("libhmi_capture.so", RTLD_NOW | RTLD_GLOBAL);
    if (st.lib) {
      st.present_fn = reinterpret_cast<HmiCapturePresentFn>(
          dlsym(st.lib, "hmi_capture_on_present"));
    }
  }
  if (!st.present_fn) {
    return;
  }

  st.surface = self;
  int viewport[4] = {0, 0, 0, 0};
  auto glGetIntegerv = reinterpret_cast<GlGetIntegervFn>(
      self->GlProcResolver("glGetIntegerv"));
  int width = 0;
  int height = 0;
  if (glGetIntegerv) {
    glGetIntegerv(kGlViewport, viewport);
    width = viewport[2];
    height = viewport[3];
  }
  if (width <= 0 || height <= 0) {
    return;
  }
  st.present_fn(&SurfaceGlGetProcThunk, width, height);
}

}  // namespace

SurfaceGl::SurfaceGl(std::unique_ptr<ContextEgl> context) {
  context_ = std::move(context);
}

bool SurfaceGl::GLContextMakeCurrent() const {
  return onscreen_surface_->MakeCurrent();
}

bool SurfaceGl::GLContextClearCurrent() const {
  return context_->ClearCurrent();
}

bool SurfaceGl::GLContextPresent(uint32_t /*fbo_id*/) const {
  MaybeHmiCapturePresent(this);
  if (!onscreen_surface_->SwapBuffers()) {
    return false;
  }
  native_window_->SwapBuffers();
  return true;
}

bool SurfaceGl::GLContextPresentWithInfo(const FlutterPresentInfo *info) const {
  MaybeHmiCapturePresent(this);
  if (!onscreen_surface_->SwapBuffers(info)) {
    return false;
  }
  native_window_->SwapBuffers();
  return true;
}

void SurfaceGl::PopulateExistingDamage(const intptr_t fbo_id,
                                       FlutterDamage *existing_damage) const {
  onscreen_surface_->PopulateExistingDamage(fbo_id, existing_damage);
}

uint32_t SurfaceGl::GLContextFBO() const {
  return 0;
}

void *SurfaceGl::GlProcResolver(const char *name) const {
  return context_->GlProcResolver(name);
}

}  // namespace flutter
