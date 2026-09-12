# frozen_string_literal: true

require "fileutils"

EXT_DIR   = __dir__
GEM_ROOT  = File.expand_path("../../..", EXT_DIR)
VENDOR    = File.join(GEM_ROOT, "vendor", "stable-diffusion.cpp")
BUILD_DIR = File.join(EXT_DIR, "build")
NATIVE    = File.join(GEM_ROOT, "ext", "elelem", "diffusion", "native")
DARWIN = RbConfig::CONFIG["host_os"] =~ /darwin/

class BuildError < StandardError; end

def run(*cmd)
  warn "elelem: + #{cmd.join(" ")}"
  system(*cmd) || raise(BuildError, "build step failed: #{cmd.join(" ")}")
end

def configure_and_build
  run(
    "cmake", "-S", VENDOR, "-B", BUILD_DIR,
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
    "-DSD_BUILD_SHARED_LIBS=OFF",
    "-DSD_BUILD_EXAMPLES=OFF",
    "-DSD_WEBP=OFF",
    "-DSD_WEBM=OFF"
  )
  run("cmake", "--build", BUILD_DIR, "--target", "stable-diffusion", "--parallel")
end

unless File.exist?(File.join(VENDOR, "CMakeLists.txt"))
  abort "elelem: vendored stable-diffusion.cpp missing at #{VENDOR}\n        " \
        "run: git submodule update --init --recursive"
end

def find_archive(name)
  Dir.glob(File.join(BUILD_DIR, "**", "#{name}.a")).first ||
    abort("elelem: could not find #{name}.a under #{BUILD_DIR}")
end

def link_shim
  ext = DARWIN ? "dylib" : "so"
  shim = File.join(NATIVE, "libelelem_diffusion.#{ext}")
  FileUtils.mkdir_p(NATIVE)

  sd_archive = find_archive("libstable-diffusion")
  ggml_archives = Dir.glob(File.join(BUILD_DIR, "ggml", "src", "**", "*.a"))

  cxx = ENV["CXX"] || "c++"
  whole_archive = DARWIN ? [] : ["-Wl,--whole-archive", sd_archive, *ggml_archives, "-Wl,--no-whole-archive"]
  force_loaded = ggml_archives.flat_map { |a| ["-Wl,-force_load,#{a}"] }
  archive_flags = DARWIN ? ["-Wl,-force_load,#{sd_archive}", *force_loaded] : whole_archive
  visibility_flags = DARWIN ? [] : ["-Wl,--exclude-libs,ALL"]
  omp_flags = DARWIN ? [] : ["-fopenmp"]
  omp_link_flags = DARWIN ? [] : ["-lgomp"]
  link_flags = DARWIN ? ["-Wl,-install_name,@rpath/libelelem_diffusion.dylib"] : []

  run(cxx, "-std=c++17", "-O2", "-Wall", "-Wextra", "-shared", "-fPIC", "-fvisibility=hidden", *omp_flags,
      "-I", File.join(VENDOR, "include"),
      "-I", File.join(VENDOR, "thirdparty"),
      File.join(EXT_DIR, "elelem.cpp"),
      "-o", shim,
      *archive_flags,
      *visibility_flags, *link_flags, *omp_link_flags, "-lpthread")
end

begin
  warn "elelem: building stable-diffusion.cpp"
  configure_and_build
  link_shim
rescue BuildError => e
  abort "elelem: build failed: #{e.message}"
end

File.write(File.join(EXT_DIR, "Makefile"), <<~MAKE)
  all:
  clean:
  install:
  .PHONY: all clean install
MAKE

warn "elelem: built stable-diffusion.cpp + shim into #{NATIVE}"
