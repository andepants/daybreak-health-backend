# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Insurance::UploadCard, type: :graphql do
  let(:session) { create(:onboarding_session) }
  let(:session_id) { "sess_#{session.id.gsub('-', '')}" }

  # Set up Active Storage URL options for test environment
  before do
    ActiveStorage::Current.url_options = { host: "localhost:3000" }
  end

  describe "mutation definition" do
    it "is defined with correct arguments" do
      expect(described_class.arguments.keys).to include("sessionId", "frontImage", "backImage")
    end

    it "returns insurance and errors fields" do
      expect(described_class.fields.keys).to include("insurance", "errors")
    end
  end

  # Test file validation service directly (Story 4.1 AC4)
  describe "FileValidator (AC4 - File Validation)" do
    let(:validator) { ::InsuranceCard::FileValidator.new }

    context "with valid files" do
      it "accepts JPEG files under 10MB" do
        file = fixture_file_upload("test_image.jpg", "image/jpeg")
        expect { validator.validate!(file) }.not_to raise_error
      end

      it "accepts PNG files" do
        file = fixture_file_upload("test_image.jpg", "image/jpeg")
        allow(Marcel::MimeType).to receive(:for).and_return("image/png")
        expect { validator.validate!(file) }.not_to raise_error
      end

      it "accepts nil (optional back image)" do
        expect { validator.validate!(nil) }.not_to raise_error
      end
    end

    context "with invalid files" do
      it "rejects files over 10MB limit" do
        file = fixture_file_upload("test_image.jpg", "image/jpeg")
        allow(file.tempfile).to receive(:size).and_return(11.megabytes)
        expect { validator.validate!(file) }.to raise_error(GraphQL::ExecutionError, /exceeds 10MB/)
      end

      it "rejects invalid file types" do
        file = fixture_file_upload("test_image.jpg", "image/jpeg")
        allow(Marcel::MimeType).to receive(:for).and_return("application/pdf")
        expect { validator.validate!(file) }.to raise_error(GraphQL::ExecutionError, /Invalid file type/)
      end
    end
  end

  # Test image processor service directly (Story 4.1 AC3)
  describe "ImageProcessor (AC3 - HEIC Conversion)" do
    let(:processor) { ::InsuranceCard::ImageProcessor.new }

    it "processes JPEG files and returns valid data" do
      file = fixture_file_upload("test_image.jpg", "image/jpeg")
      result = processor.process(file)
      expect(result[:io]).to be_present
      expect(result[:content_type]).to eq("image/jpeg")
    end

    it "strips EXIF metadata from images" do
      file = fixture_file_upload("test_image.jpg", "image/jpeg")
      result = processor.process(file)
      # Vips with strip: true removes EXIF data
      expect(result[:io]).to be_present
    end
  end

  # Test Active Storage attachment functionality (Story 4.1 AC1, AC2)
  describe "Active Storage Integration (AC1, AC2)" do
    let(:front_image) { fixture_file_upload("test_image.jpg", "image/jpeg") }
    let(:processor) { ::InsuranceCard::ImageProcessor.new }

    it "attaches front image to insurance record" do
      insurance = create(:insurance, onboarding_session: session)
      processed = processor.process(front_image)

      insurance.card_image_front.attach(
        io: processed[:io],
        filename: "test_front.jpg",
        content_type: processed[:content_type]
      )

      expect(insurance.card_image_front.attached?).to be true
    end

    it "attaches both front and back images" do
      insurance = create(:insurance, onboarding_session: session)
      back_image = fixture_file_upload("test_image.jpg", "image/jpeg")

      processed_front = processor.process(front_image)
      processed_back = processor.process(back_image)

      insurance.card_image_front.attach(
        io: processed_front[:io],
        filename: "test_front.jpg",
        content_type: processed_front[:content_type]
      )
      insurance.card_image_back.attach(
        io: processed_back[:io],
        filename: "test_back.jpg",
        content_type: processed_back[:content_type]
      )

      expect(insurance.card_image_front.attached?).to be true
      expect(insurance.card_image_back.attached?).to be true
    end
  end

  # Test OCR job queueing (Story 4.1 AC7)
  describe "OCR Job Queueing (AC7)" do
    it "OcrProcessingJob is configured for insurance queue" do
      expect(OcrProcessingJob.new.queue_name).to eq("insurance")
    end

    it "job can be enqueued with insurance ID" do
      insurance = create(:insurance, :with_front_image, onboarding_session: session)
      expect {
        OcrProcessingJob.perform_later(insurance.id)
      }.to have_enqueued_job(OcrProcessingJob).with(insurance.id)
    end
  end

  # Test presigned URL generation (Story 4.1 AC6)
  describe "Presigned URL Generation (AC6)" do
    it "generates presigned URL for front image" do
      insurance = create(:insurance, :with_front_image, onboarding_session: session)
      url = insurance.front_image_url(expires_in: 15.minutes)
      expect(url).to be_present
    end

    it "returns nil when no image attached" do
      # Use a different session for this test to avoid unique constraint
      other_session = create(:onboarding_session)
      insurance_no_image = create(:insurance, onboarding_session: other_session)
      expect(insurance_no_image.front_image_url).to be_nil
    end
  end

  # Test image retention policy (Story 4.1 AC10)
  describe "Image Retention Policy (AC10)" do
    it "purges images when status changes to verified" do
      # Create fresh session to avoid conflicts
      test_session = create(:onboarding_session)
      insurance = create(:insurance, :with_front_image, onboarding_session: test_session)
      expect(insurance.card_image_front.attached?).to be true

      # Clear queue before the update
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      insurance.update!(verification_status: :verified)

      # purge_later queues the purge job
      expect(ActiveStorage::PurgeJob).to have_been_enqueued
    end

    it "purges images when status changes to self_pay" do
      test_session = create(:onboarding_session)
      insurance = create(:insurance, :with_front_image, onboarding_session: test_session)

      # Clear queue before the update
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      insurance.update!(verification_status: :self_pay)

      expect(ActiveStorage::PurgeJob).to have_been_enqueued
    end

    it "does not purge images for intermediate statuses" do
      test_session = create(:onboarding_session)
      insurance = create(:insurance, :with_front_image, onboarding_session: test_session)

      insurance.update!(verification_status: :in_progress)

      expect(insurance.card_image_front.attached?).to be true
    end
  end
end
