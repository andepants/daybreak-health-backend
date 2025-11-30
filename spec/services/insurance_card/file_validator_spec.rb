# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsuranceCard::FileValidator do
  let(:validator) { described_class.new }

  describe "#validate!" do
    context "with a valid JPEG file" do
      let(:file) do
        fixture_file_upload("test_image.jpg", "image/jpeg")
      end

      it "returns true" do
        expect(validator.validate!(file)).to eq(true)
      end
    end

    context "with a nil file" do
      it "returns true (optional back image)" do
        expect(validator.validate!(nil)).to eq(true)
      end
    end

    context "with an oversized file" do
      let(:file) do
        fixture_file_upload("test_image.jpg", "image/jpeg")
      end

      before do
        # Mock the tempfile to return a large size
        allow(file).to receive(:tempfile).and_return(
          double(size: 11.megabytes)
        )
      end

      it "raises a GraphQL execution error" do
        expect { validator.validate!(file) }.to raise_error(GraphQL::ExecutionError) do |error|
          expect(error.message).to include("exceeds 10MB limit")
          expect(error.extensions[:code]).to eq("VALIDATION_ERROR")
        end
      end
    end

    context "with an invalid file type" do
      let(:file) do
        # Create a file with PDF magic bytes
        temp = Tempfile.new(["test", ".pdf"])
        temp.binmode
        temp.write("%PDF-1.4")
        temp.rewind
        temp
      end

      after do
        file.close
        file.unlink
      end

      it "raises a GraphQL execution error" do
        expect { validator.validate!(file) }.to raise_error(GraphQL::ExecutionError) do |error|
          expect(error.message).to include("Invalid file type")
          expect(error.extensions[:code]).to eq("VALIDATION_ERROR")
        end
      end
    end

    context "with a PNG file" do
      let(:file) do
        # Create a minimal PNG file
        temp = Tempfile.new(["test", ".png"])
        temp.binmode
        # PNG magic bytes + minimal header
        temp.write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A].pack("C*"))
        temp.write([0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52].pack("C*"))
        temp.write([0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01].pack("C*"))
        temp.write([0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE].pack("C*"))
        temp.rewind
        temp
      end

      after do
        file.close
        file.unlink
      end

      it "returns true (PNG is allowed)" do
        expect(validator.validate!(file)).to eq(true)
      end
    end
  end
end
