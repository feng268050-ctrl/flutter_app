/*
 * libhmi_capture — Flutter eLinux present-hook readback + GStreamer/MPP encode.
 *
 * Control (Dart FFI / host via App watcher):
 *   hmi_capture_screenshot / record_start / record_stop / status / cleanup
 *
 * Embedder (patched SurfaceGl, same process):
 *   hmi_capture_on_present(get_proc, width, height) before eglSwapBuffers
 */
#ifndef HMI_CAPTURE_H_
#define HMI_CAPTURE_H_

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *(*hmi_capture_gl_get_proc_fn)(const char *name);

/* Arm one-shot still; next present encodes JPEG to out_dir/screen.jpg. */
int hmi_capture_screenshot(const char *out_dir, int rotate_deg, int q_factor);

/* Start continuous record into out_dir/screen.mp4. audio: 0=off, 1=try ALSA. */
int hmi_capture_record_start(const char *out_dir,
                             int fps,
                             int scale_pct,
                             int rotate_deg,
                             int audio);

int hmi_capture_record_stop(void);

/* Write short status into buf (idle|armed|recording|done|error:…). */
int hmi_capture_status(char *buf, size_t buflen);

/* Best-effort rm -rf of a staging directory after host pull. */
int hmi_capture_cleanup(const char *path);

/* Called from SurfaceGl present path while the onscreen GL context is current. */
void hmi_capture_on_present(hmi_capture_gl_get_proc_fn get_proc,
                            int width,
                            int height);

#ifdef __cplusplus
}
#endif

#endif /* HMI_CAPTURE_H_ */
