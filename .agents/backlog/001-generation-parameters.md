As a `user generating images and video with elelem-diffusion`, I
`want to set the seed, negative prompt, video size and output format`,
so that `I can reproduce or vary results and get the file type I asked
for`.

# SYNOPSIS

Expose seed, negative prompt and video size as tool parameters, and
write the format the path asks for.

# DESCRIPTION

The Ruby methods accept `seed:` and `negative_prompt:`
(diffusion.rb:54, :63, :73), but the tools never pass them, so every
image, edit and video uses seed 42 and an empty negative prompt
(diffusion.rb:146-155, :170-173). Every run of the same prompt gives
the same image.

The `image` tool exposes width and height, but the `video` tool does
not (diffusion.rb:162-168), so video is always 512x512.

Output is always PNG: the shim writes with `stbi_write_png` whatever
the path's extension (elelem.cpp:33-34), so `out.jpg` is a PNG file
with a `.jpg` name. Video is written as numbered PNG frames
(elelem.cpp:202), which the tool description says, but there is no
option to get a single video file.

Proposed:

* `seed` (integer; omit for a random seed, and return the seed used)
  and `negative_prompt` (string) on `image` and `video`.
* `width` and `height` on `video`.
* Write JPEG when the path ends in `.jpg` or `.jpeg`, PNG for `.png`,
  and return an error for other extensions.
* Decide in design whether to assemble frames into a video file (for
  example with ffmpeg when present) or keep frames only.

# SEE ALSO

* [ ] lib/elelem/diffusion.rb:54-93 - generate, img2img, video
* [ ] lib/elelem/diffusion.rb:126-174 - image and video tools
* [ ] ext/elelem/diffusion/elelem.cpp:33 - el_sd_write_png
* [ ] ext/elelem/diffusion/elelem.cpp:202 - frame paths
* [ ] Formerly elelem-sh/elelem.sh#39

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] Two `image` calls with the same prompt and no seed give
      different images, and each result includes the seed used
* [ ] The same prompt and seed give the same image
* [ ] `negative_prompt` reaches the native call
* [ ] `video` honors `width` and `height`
* [ ] A `.jpg` path produces a JPEG file
* [ ] Specs cover parameter passing for each tool
