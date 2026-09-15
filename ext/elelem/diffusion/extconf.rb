# frozen_string_literal: true

require "fileutils"

EXT_DIR   = __dir__
GEM_ROOT  = File.expand_path("../../..", EXT_DIR)
VENDOR    = File.join(GEM_ROOT, "vendor", "stable-diffusion.cpp")
BUILD_DIR = File.join(EXT_DIR, "build")
NATIVE    = File.join(GEM_ROOT, "ext", "elelem", "diffusion", "native")
STAMP     = File.join(BUILD_DIR, ".elelem_backend")
VALID_BACKENDS = %w[cpu vulkan cuda hip metal].freeze
DARWIN = RbConfig::CONFIG["host_os"] =~ /darwin/

class BuildError < StandardError; end

def run(*cmd)
  warn "elelem: + #{cmd.join(" ")}"
  system(*cmd) || raise(BuildError, "build step failed: #{cmd.join(" ")}")
end

def which(cmd)
  ENV["PATH"].to_s.split(File::PATH_SEPARATOR).any? do |dir|
    path = File.join(dir, cmd)
    File.executable?(path) && !File.directory?(path)
  end
end

def hip_gfx_target
  out = `rocminfo 2>/dev/null`
  targets = out.scan(/gfx[0-9a-f]+/).uniq
  targets.max_by(&:length)
rescue Errno::ENOENT
  nil
end

def hip_available?
  which("hipcc") && !hip_gfx_target.nil?
end

def vulkan_loader?
  return true if which("vulkaninfo")

  %w[/usr/lib64 /usr/lib /usr/local/lib /lib64 /lib].any? do |dir|
    !Dir.glob(File.join(dir, "libvulkan.so*")).empty?
  end
end

def gpu_flags(backend)
  {
    "cpu" => [],
    "vulkan" => ["-DSD_VULKAN=ON"],
    "cuda" => ["-DSD_CUDA=ON"],
    "hip" => ["-DSD_HIPBLAS=ON", "-DCMAKE_C_COMPILER=hipcc", "-DCMAKE_CXX_COMPILER=hipcc",
              "-DAMDGPU_TARGETS=#{ENV.fetch("ELELEM_HIP_ARCH") { hip_gfx_target || "gfx1100" }}"],
    "metal" => ["-DSD_METAL=ON"]
  }.fetch(backend) { abort "elelem: unknown backend #{backend.inspect}" }
end

def detect_backend
  forced = ENV["ELELEM_SD_BACKEND"].to_s.strip.downcase
  unless forced.empty? || forced == "auto" || VALID_BACKENDS.include?(forced)
    abort "elelem: ELELEM_SD_BACKEND=#{forced.inspect} invalid; use auto|#{VALID_BACKENDS.join("|")}"
  end
  return forced unless forced.empty? || forced == "auto"

  return "metal" if DARWIN
  return "cuda" if which("nvcc")
  return "vulkan" if which("glslc") && vulkan_loader?
  return "hip" if hip_available?

  "cpu"
end

def configure_and_build(backend)
  flags = gpu_flags(backend)
  run(
    "cmake", "-S", VENDOR, "-B", BUILD_DIR,
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
    "-DSD_BUILD_SHARED_LIBS=OFF",
    "-DSD_BUILD_EXAMPLES=OFF",
    "-DSD_WEBP=OFF",
    "-DSD_WEBM=OFF",
    *flags
  )
  run("cmake", "--build", BUILD_DIR, "--target", "stable-diffusion", "--parallel")
  File.write(STAMP, backend)
end

unless File.exist?(File.join(VENDOR, "CMakeLists.txt"))
  abort "elelem: vendored stable-diffusion.cpp missing at #{VENDOR}\n        " \
        "run: git submodule update --init --recursive"
end

backend = detect_backend

if File.exist?(STAMP) && File.read(STAMP).strip != backend
  warn "elelem: backend changed -> wiping #{BUILD_DIR}"
  FileUtils.rm_rf(BUILD_DIR)
end

def find_archive(name)
  Dir.glob(File.join(BUILD_DIR, "**", "#{name}.a")).first ||
    abort("elelem: could not find #{name}.a under #{BUILD_DIR}")
end

def link_shim(backend)
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
  backend_link_flags = {
    "hip" => ["-lamdhip64", "-lhipblas", "-lrocblas"],
    "vulkan" => ["-lvulkan"],
    "cuda" => ["-lcudart", "-lcublas"]
  }.fetch(backend, [])
  link_flags = DARWIN ? ["-Wl,-install_name,@rpath/libelelem_diffusion.dylib"] : []

  run(cxx, "-std=c++17", "-O2", "-Wall", "-Wextra", "-shared", "-fPIC", "-fvisibility=hidden", *omp_flags,
      "-I", File.join(VENDOR, "include"),
      "-I", File.join(VENDOR, "thirdparty"),
      File.join(EXT_DIR, "elelem.cpp"),
      "-o", shim,
      *archive_flags,
      *visibility_flags, *link_flags, *omp_link_flags, *backend_link_flags, "-lpthread")
end

begin
  warn "elelem: building stable-diffusion.cpp backend=#{backend}"
  configure_and_build(backend)
  link_shim(backend)
rescue BuildError => e
  raise if backend == "cpu"

  warn "elelem: #{backend} build failed (#{e.message}); falling back to CPU"
  FileUtils.rm_rf(BUILD_DIR)
  backend = "cpu"
  configure_and_build(backend)
  link_shim(backend)
end

File.write(File.join(NATIVE, "backend"), backend)
File.write(File.join(EXT_DIR, "Makefile"), <<~MAKE)
  all:
  clean:
  install:
  .PHONY: all clean install
MAKE

warn "elelem: built stable-diffusion.cpp + shim into #{NATIVE} (backend=#{backend})"
