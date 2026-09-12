# frozen_string_literal: true

RSpec.describe Elelem::Diffusion do
  around do |example|
    original = ENV.fetch("ELELEM_SD_IMAGE_MODEL", nil)
    ENV["ELELEM_SD_IMAGE_MODEL"] = "/models/sd.gguf"
    example.run
  ensure
    ENV["ELELEM_SD_IMAGE_MODEL"] = original
  end

  before do
    described_class::CONTEXTS.clear
  end

  let(:open_fn) { instance_double(Fiddle::Function, call: handle) }
  let(:open_video_fn) { instance_double(Fiddle::Function, call: handle) }
  let(:generate_fn) { instance_double(Fiddle::Function) }
  let(:img2img_fn) { instance_double(Fiddle::Function) }
  let(:video_fn) { instance_double(Fiddle::Function) }
  let(:upscale_fn) { instance_double(Fiddle::Function) }
  let(:close_fn) { instance_double(Fiddle::Function, call: nil) }
  let(:handle) { instance_double(Fiddle::Pointer, null?: false) }

  before do
    allow(described_class).to receive(:functions).and_return(
      open: open_fn, open_video: open_video_fn, generate: generate_fn, img2img: img2img_fn,
      video: video_fn, upscale: upscale_fn, close: close_fn
    )
  end

  describe ".generate" do
    it "returns ok and the path on success" do
      allow(generate_fn).to receive(:call).and_return(1)

      result = described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(result).to eq(ok: true, path: "/tmp/cat.png")
    end

    it "returns ok: false when generation fails" do
      allow(generate_fn).to receive(:call).and_return(0)

      result = described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(result).to eq(ok: false, error: "generation failed")
    end

    it "returns ok: false without generating when the model fails to load" do
      allow(open_fn).to receive(:call).and_return(instance_double(Fiddle::Pointer, null?: true))
      allow(generate_fn).to receive(:call)

      result = described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(result).to eq(ok: false, error: "failed to load model at /models/sd.gguf")
      expect(generate_fn).not_to have_received(:call)
    end

    it "defaults steps/width/height/negative_prompt/seed and passes them to the shim" do
      allow(generate_fn).to receive(:call).and_return(1)

      described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(generate_fn).to have_received(:call).with(handle, "a cat", "", 512, 512, 20, 42, "/tmp/cat.png")
    end

    it "reuses the same context across calls for the same model" do
      allow(generate_fn).to receive(:call).and_return(1)

      described_class.generate(prompt: "a cat", path: "/tmp/cat.png")
      described_class.generate(prompt: "a dog", path: "/tmp/dog.png")

      expect(open_fn).to have_received(:call).once
    end

    it "does not close the context after generating" do
      allow(generate_fn).to receive(:call).and_return(1)

      described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(close_fn).not_to have_received(:call)
    end

    it "returns ok: false instead of raising when ELELEM_SD_IMAGE_MODEL is unset" do
      ENV.delete("ELELEM_SD_IMAGE_MODEL")

      result = described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(result).to eq(ok: false, error: "ELELEM_SD_IMAGE_MODEL is not set")
    end
  end

  describe ".img2img" do
    it "returns ok and the path on success" do
      allow(img2img_fn).to receive(:call).and_return(1)

      result = described_class.img2img(prompt: "make it blue", input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(result).to eq(ok: true, path: "/tmp/out.png")
    end

    it "passes strength and negative_prompt defaults to the shim" do
      allow(img2img_fn).to receive(:call).and_return(1)

      described_class.img2img(prompt: "make it blue", input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(img2img_fn).to have_received(:call).with(handle, "make it blue", "", "/tmp/in.png", 0.5, 20, 42,
                                                      "/tmp/out.png")
    end

    it "returns ok: false when img2img fails" do
      allow(img2img_fn).to receive(:call).and_return(0)

      result = described_class.img2img(prompt: "make it blue", input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(result).to eq(ok: false, error: "img2img failed")
    end
  end

  describe ".video" do
    around do |example|
      original = { model: ENV.fetch("ELELEM_SD_VIDEO_MODEL", nil), vae: ENV.fetch("ELELEM_SD_VIDEO_VAE", nil),
                   t5xxl: ENV.fetch("ELELEM_SD_VIDEO_T5XXL", nil) }
      ENV["ELELEM_SD_VIDEO_MODEL"] = "/models/wan.safetensors"
      ENV["ELELEM_SD_VIDEO_VAE"] = "/models/wan_vae.safetensors"
      ENV["ELELEM_SD_VIDEO_T5XXL"] = "/models/t5xxl.gguf"
      example.run
    ensure
      ENV["ELELEM_SD_VIDEO_MODEL"] = original[:model]
      ENV["ELELEM_SD_VIDEO_VAE"] = original[:vae]
      ENV["ELELEM_SD_VIDEO_T5XXL"] = original[:t5xxl]
    end

    it "creates the output directory and returns ok on success" do
      allow(video_fn).to receive(:call).and_return(1)
      allow(FileUtils).to receive(:mkdir_p)

      result = described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(FileUtils).to have_received(:mkdir_p).with("/tmp/vid")
      expect(result).to eq(ok: true, path: "/tmp/vid")
    end

    it "opens the video context with the diffusion/vae/t5xxl paths" do
      allow(video_fn).to receive(:call).and_return(1)
      allow(FileUtils).to receive(:mkdir_p)

      described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(open_video_fn).to have_received(:call).with(
        "/models/wan.safetensors", "/models/wan_vae.safetensors", "/models/t5xxl.gguf", Etc.nprocessors
      )
    end

    it "defaults video_frames/fps/steps and passes them to the shim" do
      allow(video_fn).to receive(:call).and_return(1)
      allow(FileUtils).to receive(:mkdir_p)

      described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(video_fn).to have_received(:call).with(handle, "a bird flying", "", 512, 512, 20, 42, 16, 8, "/tmp/vid")
    end

    it "returns ok: false when generation fails" do
      allow(video_fn).to receive(:call).and_return(0)
      allow(FileUtils).to receive(:mkdir_p)

      result = described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(result).to eq(ok: false, error: "video generation failed")
    end

    it "returns ok: false without generating when the video model fails to load" do
      allow(open_video_fn).to receive(:call).and_return(instance_double(Fiddle::Pointer, null?: true))
      allow(video_fn).to receive(:call)

      result = described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(result).to eq(ok: false, error: "failed to load video model at /models/wan.safetensors")
      expect(video_fn).not_to have_received(:call)
    end

    it "returns ok: false instead of raising when ELELEM_SD_VIDEO_MODEL is unset" do
      ENV.delete("ELELEM_SD_VIDEO_MODEL")

      result = described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(result).to eq(ok: false, error: "ELELEM_SD_VIDEO_MODEL is not set")
    end

    it "returns ok: false instead of raising when ELELEM_SD_VIDEO_VAE is unset" do
      ENV.delete("ELELEM_SD_VIDEO_VAE")

      result = described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(result).to eq(ok: false, error: "ELELEM_SD_VIDEO_VAE is not set")
    end

    it "returns ok: false instead of raising when ELELEM_SD_VIDEO_T5XXL is unset" do
      ENV.delete("ELELEM_SD_VIDEO_T5XXL")

      result = described_class.video(prompt: "a bird flying", output_dir: "/tmp/vid")

      expect(result).to eq(ok: false, error: "ELELEM_SD_VIDEO_T5XXL is not set")
    end
  end

  describe ".upscale" do
    around do |example|
      original = ENV.fetch("ELELEM_SD_ESRGAN_MODEL", nil)
      ENV["ELELEM_SD_ESRGAN_MODEL"] = "/models/esrgan.pth"
      example.run
    ensure
      ENV["ELELEM_SD_ESRGAN_MODEL"] = original
    end

    it "returns ok and the path on success" do
      allow(upscale_fn).to receive(:call).and_return(1)

      result = described_class.upscale(input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(result).to eq(ok: true, path: "/tmp/out.png")
    end

    it "does not require an sd context" do
      allow(upscale_fn).to receive(:call).and_return(1)

      described_class.upscale(input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(open_fn).not_to have_received(:call)
    end

    it "returns ok: false when upscaling fails" do
      allow(upscale_fn).to receive(:call).and_return(0)

      result = described_class.upscale(input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(result).to eq(ok: false, error: "upscale failed")
    end

    it "returns ok: false instead of raising when ELELEM_SD_ESRGAN_MODEL is unset" do
      ENV.delete("ELELEM_SD_ESRGAN_MODEL")

      result = described_class.upscale(input_path: "/tmp/in.png", path: "/tmp/out.png")

      expect(result).to eq(ok: false, error: "ELELEM_SD_ESRGAN_MODEL is not set")
    end
  end

  describe ".available?" do
    it "is true when the compiled shim is present" do
      allow(File).to receive(:exist?).with(Elelem::Diffusion::SHIM).and_return(true)

      expect(described_class).to be_available
    end

    it "is false when the compiled shim is missing" do
      allow(File).to receive(:exist?).with(Elelem::Diffusion::SHIM).and_return(false)

      expect(described_class).not_to be_available
    end
  end
end
