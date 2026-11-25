# frozen_string_literal: true

require_relative "lib/elelem/diffusion/version"

Gem::Specification.new do |spec|
  spec.name = "elelem-diffusion"
  spec.version = Elelem::Diffusion::VERSION
  spec.authors = ["mo khan"]
  spec.email = ["mo@mokhan.ca"]

  spec.summary = "Local diffusion-model tools for elelem."
  spec.description = "Adds image, img2img, video, and upscale tools backed by an embedded stable-diffusion.cpp."
  spec.homepage = "https://elelem.sh"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/elelem-sh/diffusion"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = [
    "LICENSE.txt",
    "lib/elelem/diffusion.rb",
    "lib/elelem/diffusion/version.rb",
    "ext/elelem/diffusion/elelem.cpp",
    "ext/elelem/diffusion/extconf.rb"
  ]
  vendor_exclude = %r{/(examples|docs|tests|ci|assets|\.github|thirdparty/(libwebp|libwebm|cutlass))/}
  spec.files += Dir["vendor/stable-diffusion.cpp/**/*"].select do |path|
    File.file?(path) && path !~ vendor_exclude
  end
  spec.extensions = ["ext/elelem/diffusion/extconf.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "elelem", ">= 0.12", "< 1"
  spec.add_dependency "fiddle", "~> 1.1"
end
