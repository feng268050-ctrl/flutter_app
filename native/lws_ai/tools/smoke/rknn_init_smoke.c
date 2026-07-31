#include "rknn_api.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv) {
  const char* path = argc > 1 ? argv[1] : "/userdata/models/det_raw_head.rknn";
  rknn_context ctx = 0;
  int ret = rknn_init(&ctx, (void*)path, 0, 0, NULL);
  printf("rknn_init path=%s ret=%d ctx=%llu\n", path, ret, (unsigned long long)ctx);
  if (ret == 0) {
    rknn_sdk_version ver;
    if (rknn_query(ctx, RKNN_QUERY_SDK_VERSION, &ver, sizeof(ver)) == 0) {
      printf("api=%s driver=%s\n", ver.api_version, ver.drv_version);
    }
    rknn_destroy(ctx);
    printf("rknn_destroy ok\n");
    return 0;
  }
  return 1;
}
