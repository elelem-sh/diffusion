# frozen_string_literal: true

require_relative "lib/elelem/image/version"

Gem::Specification.new do |spec|
  spec.name = "elelem-image"
  spec.version = Elelem::Image::VERSION
  spec.authors = ["mo khan"]
  spec.email = ["mo@mokhan.ca"]

  spec.summary = "Local image generation tool for elelem."
  spec.description = "Adds an image tool backed by an embedded stable-diffusion.cpp to generate images from text prompts."
  spec.homepage = "https://src.mokhan.ca/elelem/image"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = [
    "LICENSE.txt",
    "lib/elelem/image.rb",
    "lib/elelem/image/version.rb",
    "ext/elelem/image/elelem.cpp",
    "ext/elelem/image/extconf.rb",
  ]
  # Only what extconf.rb's cmake build (SD_BUILD_EXAMPLES/WEBP/WEBM all OFF)
  # actually needs to configure and compile. Applies to both stable-diffusion.cpp's
  # own tree and its nested ggml submodule.
  vendor_exclude = %r{/(examples|docs|tests|ci|assets|\.github|thirdparty/libwebp|thirdparty/libwebm)/}
  spec.files += Dir["vendor/stable-diffusion.cpp/**/*"].select do |path|
    File.file?(path) && path !~ vendor_exclude
  end
  spec.extensions = ["ext/elelem/image/extconf.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "elelem", "~> 0.11"
  spec.add_dependency "fiddle", "~> 1.1"
end
