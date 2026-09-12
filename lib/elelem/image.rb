# frozen_string_literal: true

require "elelem"
require "etc"
require "fiddle"

require_relative "image/version"

module Elelem
  module Image
    NATIVE = File.expand_path("../../ext/elelem/image/native", __dir__)
    SHIM = File.join(NATIVE, "libelelem_image.#{RbConfig::CONFIG["host_os"] =~ /darwin/ ? "dylib" : "so"}")
    V = Fiddle::TYPE_VOIDP
    I = Fiddle::TYPE_INT
    L = Fiddle::TYPE_LONG_LONG

    def self.available?
      File.exist?(SHIM)
    end

    def self.functions
      @functions ||= begin
        lib = Fiddle.dlopen(SHIM)
        {
          open: Fiddle::Function.new(lib["el_sd_open"], [V, I], V),
          generate: Fiddle::Function.new(lib["el_sd_generate"], [V, V, V, I, I, I, L, V], I, need_gvl: false),
          close: Fiddle::Function.new(lib["el_sd_close"], [V], Fiddle::TYPE_VOID)
        }
      end
    end

    def self.generate(prompt:, path:, negative_prompt: "", steps: 20, width: 512, height: 512, seed: 42, n_threads: nil)
      model = ENV.fetch("ELELEM_SD_MODEL")
      handle = functions[:open].call(model, n_threads || Etc.nprocessors)
      return { ok: false, error: "failed to load model at #{model}" } if handle.null?

      begin
        ok = functions[:generate].call(handle, prompt, negative_prompt, width, height, steps, seed, path)
        ok.zero? ? { ok: false, error: "generation failed" } : { ok: true, path: path }
      ensure
        functions[:close].call(handle)
      end
    end
  end
end

Elelem.configure do |config|
  config.setup(:image) do |agent|
    unless Elelem::Image.available?
      warn "elelem-image: native extension not built, skipping image tool " \
           "(reinstall the gem or run: cd ext/elelem/image && ruby extconf.rb)"
      next
    end

    agent.toolbox.add("image",
      description: "Generate an image from a text prompt using a local Stable Diffusion model. " \
                    "Lower steps/width/height trade image quality for speed.",
      params: {
        prompt: { type: "string" },
        path: { type: "string" },
        steps: { type: "integer", description: "sample steps, default 20; below ~15 often degrades quality" },
        width: { type: "integer", description: "pixels, default 512" },
        height: { type: "integer", description: "pixels, default 512" }
      },
      required: ["prompt", "path"]
    ) do |args|
      Elelem::Image.generate(
        prompt: args["prompt"], path: args["path"],
        steps: args["steps"] || 20, width: args["width"] || 512, height: args["height"] || 512
      )
    end
  end
end
