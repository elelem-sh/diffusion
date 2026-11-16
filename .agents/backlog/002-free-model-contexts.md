As a `user generating with more than one model in a session`, I `want
model contexts freed when they are no longer needed`, so that `memory
does not grow until the process exits`.

# SYNOPSIS

Close model contexts with `el_sd_close`, and stop serializing unrelated
generations.

# DESCRIPTION

`context_for` and `video_context_for` cache each loaded model in
`CONTEXTS` and never remove it (diffusion.rb:41-52). `el_sd_close` is
bound (diffusion.rb:36) but never called, not even at exit. Changing
`ELELEM_SD_IMAGE_MODEL` between calls, or using both image and video
models, keeps every context in RAM and VRAM for the life of the
process.

A single global `MUTEX` guards both the cache and every native call
(diffusion.rb:19, :56, :66, :88, :99), so an upscale waits for an
unrelated image generation to finish.

Proposed:

* Close contexts at exit.
* Keep at most one image and one video context (or a small limit), and
  close the old one when the model changes.
* Use a lock per context instead of one global lock, if the native
  library allows concurrent use of different contexts; check in
  design.

# SEE ALSO

* [ ] lib/elelem/diffusion.rb:19-20 - MUTEX and CONTEXTS
* [ ] lib/elelem/diffusion.rb:36 - close bound, never called
* [ ] lib/elelem/diffusion.rb:41-52 - context caches
* [ ] ext/elelem/diffusion/elelem.cpp - el_sd_close
* [ ] Formerly elelem-sh/elelem.sh#39

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] Every opened context is closed by process exit
* [ ] Switching the image model closes the previous context
* [ ] An upscale does not wait on an image generation that uses another
      context, if the native library allows it
* [ ] Specs check that close is called
