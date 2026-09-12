#include "stable-diffusion.h"

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#include "stb_image.h"

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

  static bool el_sd_write_png(sd_image_t image, const char *output_path) {
    int written = stbi_write_png(output_path, image.width, image.height,
                                  image.channel, image.data,
                                  image.width * image.channel);
    return written != 0;
  }

  static bool el_sd_read_png(const char *input_path, sd_image_t *out) {
    int width, height, channels;
    unsigned char *data = stbi_load(input_path, &width, &height, &channels, 3);
    if (!data) return false;
    out->width = static_cast<uint32_t>(width);
    out->height = static_cast<uint32_t>(height);
    out->channel = 3;
    out->data = data;
    return true;
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

    bool written = el_sd_write_png(images[0], output_path);

    free(images[0].data);
    free(images);

    return written;
  }

  EL_API bool el_sd_img2img(void *handle_ptr, const char *prompt, const char *negative_prompt,
                       const char *input_path, float strength, int steps, int64_t seed,
                       const char *output_path) {
    el_sd_handle *handle = static_cast<el_sd_handle *>(handle_ptr);
    if (!handle || !handle->ctx) return false;

    sd_image_t init_image;
    if (!el_sd_read_png(input_path, &init_image)) return false;

    sd_img_gen_params_t params;
    sd_img_gen_params_init(&params);
    params.prompt = prompt;
    params.negative_prompt = negative_prompt;
    params.init_image = init_image;
    params.width = init_image.width;
    params.height = init_image.height;
    params.strength = strength;
    params.sample_params.sample_steps = steps;
    params.seed = seed;
    params.batch_count = 1;

    sd_image_t *images = nullptr;
    int num_images = 0;
    bool ok = generate_image(handle->ctx, &params, &images, &num_images);
    free(init_image.data);
    if (!ok || num_images < 1 || !images) return false;

    bool written = el_sd_write_png(images[0], output_path);

    free(images[0].data);
    free(images);

    return written;
  }

  EL_API bool el_sd_upscale(const char *esrgan_path, const char *input_path,
                       int n_threads, const char *output_path) {
    sd_image_t input_image;
    if (!el_sd_read_png(input_path, &input_image)) return false;

    upscaler_ctx_t *upscaler = new_upscaler_ctx(esrgan_path, false, n_threads, 0, nullptr, nullptr);
    if (!upscaler) {
      free(input_image.data);
      return false;
    }

    int factor = get_upscale_factor(upscaler);
    sd_image_t *images = nullptr;
    int num_images = 0;
    bool ok = upscale(upscaler, input_image, static_cast<uint32_t>(factor), &images, &num_images);
    free(input_image.data);
    free_upscaler_ctx(upscaler);
    if (!ok || num_images < 1 || !images) return false;

    bool written = el_sd_write_png(images[0], output_path);
    free(images[0].data);
    free(images);

    return written;
  }

  EL_API bool el_sd_video(void *handle_ptr, const char *prompt, const char *negative_prompt,
                     int width, int height, int steps, int64_t seed, int video_frames, int fps,
                     const char *output_dir) {
    el_sd_handle *handle = static_cast<el_sd_handle *>(handle_ptr);
    if (!handle || !handle->ctx) return false;

    sd_vid_gen_params_t params;
    sd_vid_gen_params_init(&params);
    params.prompt = prompt;
    params.negative_prompt = negative_prompt;
    params.width = width;
    params.height = height;
    params.sample_params.sample_steps = steps;
    params.seed = seed;
    params.video_frames = video_frames;
    params.fps = fps;

    sd_image_t *frames = nullptr;
    int num_frames = 0;
    sd_audio_t *audio = nullptr;
    bool ok = generate_video(handle->ctx, &params, &frames, &num_frames, &audio);
    if (audio) free_sd_audio(audio);
    if (!ok || num_frames < 1 || !frames) return false;

    bool all_written = true;
    char frame_path[4096];
    for (int i = 0; i < num_frames; i++) {
      snprintf(frame_path, sizeof(frame_path), "%s/frame-%04d.png", output_dir, i);
      if (!el_sd_write_png(frames[i], frame_path)) all_written = false;
      free(frames[i].data);
    }
    free(frames);

    return all_written;
  }

  EL_API void el_sd_close(void *handle_ptr) {
    el_sd_handle *handle = static_cast<el_sd_handle *>(handle_ptr);
    if (!handle) return;
    if (handle->ctx) free_sd_ctx(handle->ctx);
    delete handle;
  }
}
