#include "stable-diffusion.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_WRITE_STATIC
#include "stb_image_write.h"

#include <cstdio>
#include <cstring>
#include <string>

#define EL_API __attribute__((visibility("default")))

extern "C" {
  struct el_sd_handle {
    sd_ctx_t *ctx;
  };

  static void el_sd_log_cb(enum sd_log_level_t, const char *, void *) {
    // sd.cpp's INFO/progress logging goes straight to this process's stderr
    // with no subprocess boundary to contain it; drop it here. Callers that
    // want it can wire sd_set_log_callback themselves.
  }

  static void el_sd_progress_cb(int, int, float, void *) {
    // Same rationale as el_sd_log_cb: no subprocess boundary to contain the
    // progress bar sd.cpp writes straight to stderr.
  }

  EL_API void *el_sd_open(const char *model_path, int n_threads) {
    sd_ctx_params_t params;
    sd_ctx_params_init(&params);
    params.model_path = model_path;
    params.n_threads = n_threads;

    sd_set_log_callback(el_sd_log_cb, nullptr);
    sd_set_progress_callback(el_sd_progress_cb, nullptr);

    sd_ctx_t *ctx = new_sd_ctx(&params);
    if (!ctx) return nullptr;

    el_sd_handle *handle = new el_sd_handle{ctx};
    return handle;
  }

  EL_API bool el_sd_generate(void *handle_ptr, const char *prompt, const char *negative_prompt,
                       int width, int height, int steps, int64_t seed, const char *output_path) {
    el_sd_handle *handle = static_cast<el_sd_handle *>(handle_ptr);
    if (!handle || !handle->ctx) return false;

    sd_img_gen_params_t params;
    sd_img_gen_params_init(&params);
    params.prompt = prompt;
    params.negative_prompt = negative_prompt;
    params.width = width;
    params.height = height;
    params.sample_params.sample_steps = steps;
    params.seed = seed;
    params.batch_count = 1;

    sd_image_t *images = nullptr;
    int num_images = 0;
    bool ok = generate_image(handle->ctx, &params, &images, &num_images);
    if (!ok || num_images < 1 || !images) return false;

    int written = stbi_write_png(output_path, images[0].width, images[0].height,
                                  images[0].channel, images[0].data,
                                  images[0].width * images[0].channel);

    free(images[0].data);
    free(images);

    return written != 0;
  }

  EL_API void el_sd_close(void *handle_ptr) {
    el_sd_handle *handle = static_cast<el_sd_handle *>(handle_ptr);
    if (!handle) return;
    if (handle->ctx) free_sd_ctx(handle->ctx);
    delete handle;
  }
}
