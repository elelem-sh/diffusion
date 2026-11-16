As a `user who installed elelem-diffusion without a built extension`,
I `want to be told the image tools were skipped`, so that `I know why
the model has no image, video or upscale tool`.

# SYNOPSIS

Report the missing native extension in a way `ruby -W0` does not hide.

# DESCRIPTION

When the native library is missing, the setup block calls `warn` and
skips the tools (diffusion.rb:120-124). That is `Kernel#warn`, which
writes nothing when `$VERBOSE` is nil. The `elelem` executable runs
with `ruby -W0` (elelem exe/elelem:1), so under elelem the message is
never shown and the tools silently do not exist.

Use `$stderr.puts`, as core's plugin loader does
(elelem lib/elelem/plugins.rb:34), and also log it with
`Elelem.logger.warn`.

# SEE ALSO

* [ ] lib/elelem/diffusion.rb:120-124 - Kernel#warn
* [ ] elelem exe/elelem:1 - `ruby -W0`
* [ ] elelem lib/elelem/plugins.rb:34 - $stderr.puts precedent
* [ ] Formerly elelem-sh/elelem.sh#39

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] With the extension missing, `elelem chat` with the plugin loaded
      prints the message once to stderr
* [ ] The message is also in the elelem log
* [ ] A spec runs with `$VERBOSE = nil` and checks the message appears
