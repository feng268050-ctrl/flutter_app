/* Emulator VirGL: satisfy Rockchip Mali-linked Weston on Mesa GBM.
 * Built by scripts/fetch-emulator-swgl.sh into prebuilt/emulator-swgl/lib/.
 */
#include <stdint.h>

char mali_injected;

struct gbm_device;
struct gbm_bo;

int gbm_bo_get_fd(struct gbm_bo *bo);
struct gbm_bo *gbm_bo_create_with_modifiers(struct gbm_device *gbm,
					    uint32_t width, uint32_t height,
					    uint32_t format,
					    const uint64_t *modifiers,
					    const unsigned int count);

int gbm_bo_get_fd_for_plane(struct gbm_bo *bo, int plane)
{
	if (plane != 0)
		return -1;
	return gbm_bo_get_fd(bo);
}

struct gbm_bo *gbm_bo_create_with_modifiers2(struct gbm_device *gbm,
					     uint32_t width, uint32_t height,
					     uint32_t format,
					     const uint64_t *modifiers,
					     const unsigned int count,
					     uint32_t flags)
{
	(void)flags;
	return gbm_bo_create_with_modifiers(gbm, width, height, format, modifiers,
					    count);
}
