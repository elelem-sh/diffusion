As a `person who wants local image generation in elelem`, I `want a
README and tests that exercise the real library`, so that `I can set
it up and trust that the tools work`.

# SYNOPSIS

Add a README, and at least one spec that runs the native extension.

# DESCRIPTION

The repository has no README. It should cover:

* Install, build requirements, and that the gem compiles
  stable-diffusion.cpp.
* The loader file elelem needs to load a gem plugin
  (`~/.agents/plugins/diffusion.rb` containing
  `require "elelem/diffusion"`), until core loads plugins on its own.
* The tools: `image` (text to image and img2img), `video`, `upscale`.
* Environment variables: `ELELEM_SD_IMAGE_MODEL`,
  `ELELEM_SD_VIDEO_MODEL`, `ELELEM_SD_VIDEO_VAE`,
  `ELELEM_SD_VIDEO_T5XXL`, `ELELEM_SD_ESRGAN_MODEL`, with example
  models.
* Expected speed and memory.

elelem.sh has no page for this plugin yet (/plugins/diffusion/
redirects to the GitHub repository), so the README is the main
documentation for now.

The spec file stubs every `Fiddle::Function`
(spec/elelem/diffusion_spec.rb:16-20), so nothing tests the extension
itself. Add a spec, skipped when the extension or a tiny model is not
available, that runs a real generation.

# SEE ALSO

* [ ] lib/elelem/diffusion.rb - tools and environment variables
* [ ] spec/elelem/diffusion_spec.rb:16-20 - stubbed functions
* [ ] Formerly elelem-sh/elelem.sh#39

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] README.md exists and covers install, loading, tools and every
      environment variable
* [ ] Commands have no leading `$`
* [ ] At least one spec calls the real native library when it is
      available, and is skipped otherwise
