#include "ggml.h"
#include "stable-diffusion.h"

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_WRITE_STATIC
#include "stb_image_write.h"

#include <cstdio>
#include <memory>
#include <string>

#define EL_API __attribute__((visibility("default")))

namespace {
  struct Free {
    void operator()(sd_opt_t *options) const { sd_opt_free(options); }
    void operator()(sd_ctx_t *context) const { sd_ctx_free(context); }
    void operator()(sd_upscaler_t *upscaler) const { sd_upscaler_free(upscaler); }
    void operator()(sd_result_t *result) const { sd_result_free(result); }
    void operator()(sd_tensor_t *tensor) const { sd_tensor_free(tensor); }
    void operator()(stbi_uc *pixels) const { stbi_image_free(pixels); }
  };

  template <typename T>
  using Owned = std::unique_ptr<T, Free>;

  class Options {
  public:
    explicit Options(sd_opt_t *options) : options(options), ok(options != nullptr) {}

    Options &text(const char *key, const char *value) {
      return value && *value ? check(sd_opt_set_string(options.get(), key, value)) : *this;
    }

    Options &integer(const char *key, int64_t value) {
      return check(sd_opt_set_int(options.get(), key, value));
    }

    Options &number(const char *key, double value) {
      return check(sd_opt_set_float(options.get(), key, value));
    }

    Options &image(const char *key, const sd_tensor_t *value) {
      return check(sd_opt_set_tensor(options.get(), key, value));
    }

    const sd_opt_t *get() const { return options.get(); }
    explicit operator bool() const { return ok; }

  private:
    Options &check(sd_status_t status) {
      ok = ok && status == SD_STATUS_OK;
      return *this;
    }

    Owned<sd_opt_t> options;
    bool ok;
  };

  void quiet(int, int, float, void *) {}
  void quiet(enum ggml_log_level, const char *, void *) {}

  void silence() {
    ggml_log_set(quiet, nullptr);
    sd_set_progress_callback(quiet, nullptr);
  }

  Owned<sd_tensor_t> read_png(const char *path) {
    int width, height, channels;
    Owned<stbi_uc> pixels(stbi_load(path, &width, &height, &channels, 3));
    if (!pixels) return nullptr;

    const int64_t shape[] = {3, width, height};
    return Owned<sd_tensor_t>(
      sd_tensor_create(SD_TENSOR_U8, 3, shape, pixels.get(), static_cast<size_t>(width) * height * 3));
  }

  bool write_png(const sd_tensor_t *image, const char *path) {
    if (!image || !path) return false;

    int channels = static_cast<int>(sd_tensor_dim(image, 0));
    int width = static_cast<int>(sd_tensor_dim(image, 1));
    int height = static_cast<int>(sd_tensor_dim(image, 2));
    return stbi_write_png(path, width, height, channels, sd_tensor_data(image), width * channels) != 0;
  }

  template <typename Subject>
  using Operation = sd_status_t (*)(Subject *, const sd_opt_t *, sd_result_t **);

  template <typename Subject>
  Owned<sd_result_t> run(Operation<Subject> operation, Subject *subject, const Options &options) {
    sd_result_t *result = nullptr;
    if (!options || operation(subject, options.get(), &result) != SD_STATUS_OK) return nullptr;

    return Owned<sd_result_t>(result);
  }

  void *open(const Options &options, bool (*supported)(const sd_ctx_t *)) {
    silence();

    sd_ctx_t *created = nullptr;
    if (!options || sd_ctx_create(options.get(), &created) != SD_STATUS_OK) return nullptr;

    Owned<sd_ctx_t> context(created);
    return supported(context.get()) ? context.release() : nullptr;
  }
}

extern "C" {
  EL_API void *el_sd_open(const char *model_path, const char *vae_path, int n_threads) {
    Options options(sd_ctx_opt_create());
    options.text("model_path", model_path).text("vae_path", vae_path).integer("n_threads", n_threads);
    return open(options, sd_ctx_supports_image_generation);
  }

  EL_API void *el_sd_open_video(const char *diffusion_model_path, const char *vae_path,
                                const char *t5xxl_path, int n_threads) {
    Options options(sd_ctx_opt_create());
    options.text("diffusion_model_path", diffusion_model_path)
      .text("vae_path", vae_path)
      .text("t5xxl_path", t5xxl_path)
      .integer("n_threads", n_threads);
    return open(options, sd_ctx_supports_video_generation);
  }

  EL_API bool el_sd_generate(void *handle, const char *prompt, const char *negative_prompt,
                             int width, int height, int steps, int64_t seed, float cfg_scale,
                             const char *output_path) {
    Options options(sd_img_gen_opt_create());
    options.text("prompt", prompt)
      .text("negative_prompt", negative_prompt)
      .integer("width", width)
      .integer("height", height)
      .integer("sample.steps", steps)
      .integer("seed", seed)
      .integer("batch_count", 1);
    if (cfg_scale > 0) options.number("sample.guidance.txt_cfg", cfg_scale);

    auto result = run(sd_generate_image, static_cast<sd_ctx_t *>(handle), options);
    return write_png(sd_result_get_image(result.get(), 0), output_path);
  }

  EL_API bool el_sd_img2img(void *handle, const char *prompt, const char *negative_prompt,
                            const char *input_path, float strength, int steps, int64_t seed,
                            const char *output_path) {
    auto input = read_png(input_path);
    if (!input) return false;

    Options options(sd_img_gen_opt_create());
    options.text("prompt", prompt)
      .text("negative_prompt", negative_prompt)
      .image("init_image", input.get())
      .integer("width", sd_tensor_dim(input.get(), 1))
      .integer("height", sd_tensor_dim(input.get(), 2))
      .number("strength", strength)
      .integer("sample.steps", steps)
      .integer("seed", seed)
      .integer("batch_count", 1);

    auto result = run(sd_generate_image, static_cast<sd_ctx_t *>(handle), options);
    return write_png(sd_result_get_image(result.get(), 0), output_path);
  }

  EL_API bool el_sd_upscale(const char *esrgan_path, const char *input_path,
                            int n_threads, const char *output_path) {
    silence();

    Options options(sd_upscale_opt_create());
    options.image("image", read_png(input_path).get());
    if (!options) return false;

    Options model(sd_upscaler_opt_create());
    model.text("model_path", esrgan_path).integer("n_threads", n_threads);

    sd_upscaler_t *created = nullptr;
    if (!model || sd_upscaler_create(model.get(), &created) != SD_STATUS_OK) return false;

    Owned<sd_upscaler_t> upscaler(created);
    auto result = run(sd_upscale, upscaler.get(), options);
    return write_png(sd_result_get_image(result.get(), 0), output_path);
  }

  EL_API bool el_sd_video(void *handle, const char *prompt, const char *negative_prompt,
                          int width, int height, int steps, int64_t seed, int video_frames, int fps,
                          const char *output_dir) {
    Options options(sd_vid_gen_opt_create());
    options.text("prompt", prompt)
      .text("negative_prompt", negative_prompt)
      .integer("width", width)
      .integer("height", height)
      .integer("sample.steps", steps)
      .integer("seed", seed)
      .integer("video_frames", video_frames)
      .integer("fps", fps);

    auto result = run(sd_generate_video, static_cast<sd_ctx_t *>(handle), options);
    size_t frames = sd_result_get_image_count(result.get());
    bool written = frames > 0;
    for (size_t i = 0; i < frames; i++) {
      char name[32];
      snprintf(name, sizeof(name), "/frame-%04zu.png", i);
      written = write_png(sd_result_get_image(result.get(), i), (output_dir + std::string(name)).c_str()) && written;
    }
    return written;
  }

  EL_API void el_sd_close(void *handle) {
    sd_ctx_free(static_cast<sd_ctx_t *>(handle));
  }
}
