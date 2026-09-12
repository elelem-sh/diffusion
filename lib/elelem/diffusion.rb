# frozen_string_literal: true

require "elelem"
require "etc"
require "fiddle"
require "fileutils"

require_relative "diffusion/version"

module Elelem
  module Diffusion
    NATIVE = File.expand_path("../../ext/elelem/diffusion/native", __dir__)
    SHIM = File.join(NATIVE, "libelelem_diffusion.#{RbConfig::CONFIG["host_os"] =~ /darwin/ ? "dylib" : "so"}")
    V = Fiddle::TYPE_VOIDP
    I = Fiddle::TYPE_INT
    L = Fiddle::TYPE_LONG_LONG
    F = Fiddle::TYPE_FLOAT

    MUTEX = Mutex.new
    CONTEXTS = {} # rubocop:disable Style/MutableConstant

    def self.available?
      File.exist?(SHIM)
    end

    def self.functions
      @functions ||= begin
        lib = Fiddle.dlopen(SHIM)
        {
          open: Fiddle::Function.new(lib["el_sd_open"], [V, I], V),
          open_video: Fiddle::Function.new(lib["el_sd_open_video"], [V, V, V, I], V),
          generate: Fiddle::Function.new(lib["el_sd_generate"], [V, V, V, I, I, I, L, V], I, need_gvl: false),
          img2img: Fiddle::Function.new(lib["el_sd_img2img"], [V, V, V, V, F, I, L, V], I, need_gvl: false),
          video: Fiddle::Function.new(lib["el_sd_video"], [V, V, V, I, I, I, L, I, I, V], I, need_gvl: false),
          upscale: Fiddle::Function.new(lib["el_sd_upscale"], [V, V, I, V], I, need_gvl: false),
          close: Fiddle::Function.new(lib["el_sd_close"], [V], Fiddle::TYPE_VOID)
        }
      end
    end

    def self.context_for(model, n_threads: nil)
      MUTEX.synchronize do
        CONTEXTS[model] ||= functions[:open].call(model, n_threads || Etc.nprocessors)
      end
    end

    def self.video_context_for(diffusion_model, vae, t5xxl, n_threads: nil)
      key = [diffusion_model, vae, t5xxl]
      MUTEX.synchronize do
        CONTEXTS[key] ||= functions[:open_video].call(diffusion_model, vae, t5xxl, n_threads || Etc.nprocessors)
      end
    end

    def self.generate(prompt:, path:, negative_prompt: "", steps: 20, width: 512, height: 512, seed: 42, n_threads: nil)
      with_context(n_threads: n_threads) do |_model, handle|
        ok = MUTEX.synchronize do
          functions[:generate].call(handle, prompt, negative_prompt, width, height, steps, seed, path)
        end
        ok.zero? ? { ok: false, error: "generation failed" } : { ok: true, path: path }
      end
    end

    def self.img2img(prompt:, input_path:, path:, negative_prompt: "", strength: 0.5, steps: 20, seed: 42,
                     n_threads: nil)
      with_context(n_threads: n_threads) do |_model, handle|
        ok = MUTEX.synchronize do
          functions[:img2img].call(handle, prompt, negative_prompt, input_path, strength, steps, seed, path)
        end
        ok.zero? ? { ok: false, error: "img2img failed" } : { ok: true, path: path }
      end
    end

    def self.video(prompt:, output_dir:, negative_prompt: "", steps: 20, width: 512, height: 512, seed: 42,
                   video_frames: 16, fps: 8, n_threads: nil)
      diffusion_model = ENV.fetch("ELELEM_SD_VIDEO_MODEL", nil)
      return { ok: false, error: "ELELEM_SD_VIDEO_MODEL is not set" } unless diffusion_model

      vae = ENV.fetch("ELELEM_SD_VIDEO_VAE", nil)
      return { ok: false, error: "ELELEM_SD_VIDEO_VAE is not set" } unless vae

      t5xxl = ENV.fetch("ELELEM_SD_VIDEO_T5XXL", nil)
      return { ok: false, error: "ELELEM_SD_VIDEO_T5XXL is not set" } unless t5xxl

      handle = video_context_for(diffusion_model, vae, t5xxl, n_threads: n_threads)
      return { ok: false, error: "failed to load video model at #{diffusion_model}" } if handle.null?

      FileUtils.mkdir_p(output_dir)
      ok = MUTEX.synchronize do
        functions[:video].call(handle, prompt, negative_prompt, width, height, steps, seed, video_frames, fps,
                               output_dir)
      end
      ok.zero? ? { ok: false, error: "video generation failed" } : { ok: true, path: output_dir }
    end

    def self.upscale(input_path:, path:, n_threads: nil)
      esrgan = ENV.fetch("ELELEM_SD_ESRGAN_MODEL", nil)
      return { ok: false, error: "ELELEM_SD_ESRGAN_MODEL is not set" } unless esrgan

      ok = MUTEX.synchronize do
        functions[:upscale].call(esrgan, input_path, n_threads || Etc.nprocessors, path)
      end
      ok.zero? ? { ok: false, error: "upscale failed" } : { ok: true, path: path }
    end

    def self.with_context(n_threads:)
      model = ENV.fetch("ELELEM_SD_IMAGE_MODEL", nil)
      return { ok: false, error: "ELELEM_SD_IMAGE_MODEL is not set" } unless model

      handle = context_for(model, n_threads: n_threads)
      return { ok: false, error: "failed to load model at #{model}" } if handle.null?

      yield model, handle
    end
    private_class_method :with_context
  end
end

Elelem.configure do |config|
  config.setup(:diffusion) do |agent|
    unless Elelem::Diffusion.available?
      warn "elelem-diffusion: native extension not built, skipping image/video/upscale tools " \
           "(reinstall the gem or run: cd ext/elelem/diffusion && ruby extconf.rb)"
      next
    end

    agent.toolbox.add("image",
                      description: "Generate an image from a text prompt using a local Stable Diffusion model, " \
                                   "or edit an existing image by passing input_path (img2img). " \
                                   "Lower steps/width/height trade image quality for speed.",
                      params: {
                        prompt: { type: "string" },
                        path: { type: "string" },
                        input_path: { type: "string",
                                      description: "existing image to edit; omit for a fresh generation" },
                        strength: { type: "number",
                                    description: "0.0-1.0, only used with input_path; higher changes more of the " \
                                                 "original" },
                        steps: { type: "integer",
                                 description: "sample steps, default 20; below ~15 often degrades quality" },
                        width: { type: "integer",
                                 description: "pixels, default 512, ignored when editing (uses input image size)" },
                        height: { type: "integer",
                                  description: "pixels, default 512, ignored when editing (uses input image size)" }
                      },
                      required: %w[prompt path]) do |args|
      if args["input_path"]
        Elelem::Diffusion.img2img(
          prompt: args["prompt"], input_path: args["input_path"], path: args["path"],
          strength: args["strength"] || 0.5, steps: args["steps"] || 20
        )
      else
        Elelem::Diffusion.generate(
          prompt: args["prompt"], path: args["path"],
          steps: args["steps"] || 20, width: args["width"] || 512, height: args["height"] || 512
        )
      end
    end

    agent.toolbox.add("video",
                      description: "Generate a short video from a text prompt using a local Wan2.1/2.2 model. " \
                                   "Writes numbered PNG frames into output_dir. Slow: minutes per clip.",
                      params: {
                        prompt: { type: "string" },
                        output_dir: { type: "string" },
                        video_frames: { type: "integer", description: "default 16" },
                        fps: { type: "integer", description: "default 8" },
                        steps: { type: "integer", description: "sample steps, default 20" }
                      },
                      required: %w[prompt output_dir]) do |args|
      Elelem::Diffusion.video(
        prompt: args["prompt"], output_dir: args["output_dir"],
        video_frames: args["video_frames"] || 16, fps: args["fps"] || 8, steps: args["steps"] || 20
      )
    end

    agent.toolbox.add("upscale",
                      description: "Upscale an existing image with a local ESRGAN model.",
                      params: {
                        input_path: { type: "string" },
                        path: { type: "string" }
                      },
                      required: %w[input_path path]) do |args|
      Elelem::Diffusion.upscale(input_path: args["input_path"], path: args["path"])
    end
  end
end
