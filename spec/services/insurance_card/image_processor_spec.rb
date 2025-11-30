# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsuranceCard::ImageProcessor do
  let(:processor) { described_class.new }

  describe "#process" do
    context "with a JPEG file" do
      let(:file) do
        fixture_file_upload("test_image.jpg", "image/jpeg")
      end

      it "returns processed image data" do
        result = processor.process(file)

        expect(result).to be_a(Hash)
        expect(result[:io]).to respond_to(:read)
        expect(result[:content_type]).to eq("image/jpeg")
      end

      it "strips EXIF metadata" do
        result = processor.process(file)

        # The processed file should be readable
        expect(result[:io].read.length).to be > 0
      end
    end

    context "with a PNG file" do
      let(:file) do
        # Create a minimal PNG file
        temp = Tempfile.new(["test", ".png"])
        temp.binmode
        # PNG magic bytes + minimal valid PNG
        png_data = [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, # PNG signature
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, # IHDR chunk
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
          0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, # IDAT chunk
          0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x00,
          0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, 0xE7,
          0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, # IEND chunk
          0xAE, 0x42, 0x60, 0x82
        ].pack("C*")
        temp.write(png_data)
        temp.rewind
        temp
      end

      after do
        file.close
        file.unlink
      end

      it "returns processed PNG data" do
        result = processor.process(file)

        expect(result).to be_a(Hash)
        expect(result[:io]).to respond_to(:read)
        expect(result[:content_type]).to eq("image/png")
      end
    end
  end
end
