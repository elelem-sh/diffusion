As a `contributor cloning elelem-diffusion`, I `want bin/setup to fetch
the vendored stable-diffusion.cpp`, so that `the first build works
without a manual git step`.

# SYNOPSIS

Run `git submodule update --init --recursive` in bin/setup.

# DESCRIPTION

stable-diffusion.cpp is a git submodule at vendor/stable-diffusion.cpp
(.gitmodules), and it has submodules of its own. bin/setup runs only
`bundle install`, so after a plain clone the vendored source is missing
and the native build fails until the contributor runs
`git submodule update --init --recursive` by hand. elelem-llama's
bin/setup already does this.

# SEE ALSO

* [ ] bin/setup
* [ ] .gitmodules - vendor/stable-diffusion.cpp
* [ ] elelem-llama bin/setup - does the same step
* [ ] Formerly elelem-sh/elelem.sh#40

# Tasks

* [ ] TBD (filled in design mode)

# Acceptance Criteria

* [ ] After a fresh clone without `--recursive`, bin/setup followed by
      bin/compile succeeds
* [ ] bin/setup is still safe to run twice
