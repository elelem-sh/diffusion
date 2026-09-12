# frozen_string_literal: true

RSpec.describe Elelem::Image do
  describe ".generate" do
    around do |example|
      original = ENV["ELELEM_SD_MODEL"]
      ENV["ELELEM_SD_MODEL"] = "/models/sd.gguf"
      example.run
    ensure
      ENV["ELELEM_SD_MODEL"] = original
    end

    let(:open_fn) { instance_double(Fiddle::Function, call: handle) }
    let(:generate_fn) { instance_double(Fiddle::Function) }
    let(:close_fn) { instance_double(Fiddle::Function, call: nil) }
    let(:handle) { instance_double(Fiddle::Pointer, null?: false) }

    before do
      allow(described_class).to receive(:functions).and_return(open: open_fn, generate: generate_fn, close: close_fn)
    end

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

    it "closes the context even when generation fails" do
      allow(generate_fn).to receive(:call).and_return(0)

      described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(close_fn).to have_received(:call).with(handle)
    end

    it "defaults steps/width/height/negative_prompt/seed and passes them to the shim" do
      allow(generate_fn).to receive(:call).and_return(1)

      described_class.generate(prompt: "a cat", path: "/tmp/cat.png")

      expect(generate_fn).to have_received(:call).with(handle, "a cat", "", 512, 512, 20, 42, "/tmp/cat.png")
    end
  end

  describe ".available?" do
    it "is true when the compiled shim is present" do
      allow(File).to receive(:exist?).with(Elelem::Image::SHIM).and_return(true)

      expect(described_class).to be_available
    end

    it "is false when the compiled shim is missing" do
      allow(File).to receive(:exist?).with(Elelem::Image::SHIM).and_return(false)

      expect(described_class).not_to be_available
    end
  end
end
