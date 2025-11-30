# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe InsuranceServices::CardParser, type: :service do
  let(:insurance) { create(:insurance, :with_front_image) }

  # Mock Textract response for testing
  let(:mock_textract_client) { instance_double(Aws::Textract::Client) }

  before do
    allow(AwsClients).to receive(:textract).and_return(mock_textract_client)

    # Configure Active Storage service_configurations for tests
    # service_configurations may be nil in test environment, so initialize it
    Rails.configuration.active_storage.service_configurations ||= {}
    Rails.configuration.active_storage.service_configurations["amazon"] = { "bucket" => "test-bucket" }
  end

  describe "#call" do
    context "with successful Textract response" do
      let(:textract_response) do
        # Simplified mock of Textract response structure
        OpenStruct.new(
          document_metadata: OpenStruct.new(pages: 1),
          analyze_document_model_version: "1.0",
          blocks: build_textract_blocks
        )
      end

      before do
        allow(mock_textract_client).to receive(:analyze_document).and_return(textract_response)
      end

      it "returns parsed result with status" do
        result = described_class.call(insurance)

        expect(result).to be_a(Hash)
        expect(result[:status]).to be_in([:ocr_complete, :ocr_needs_review])
        expect(result[:data]).to be_a(Hash)
        expect(result[:raw]).to be_a(Hash)
      end

      it "extracts fields with confidence scores" do
        result = described_class.call(insurance)

        expect(result[:data][:extracted_fields]).to be_a(Hash)
        expect(result[:data][:confidence_scores]).to be_a(Hash)
      end

      it "identifies low confidence fields" do
        result = described_class.call(insurance)

        expect(result[:data]).to have_key(:low_confidence_fields)
        expect(result[:data]).to have_key(:needs_review)
      end
    end

    context "with high confidence extraction" do
      let(:textract_response) do
        OpenStruct.new(
          document_metadata: OpenStruct.new(pages: 1),
          analyze_document_model_version: "1.0",
          blocks: build_textract_blocks(confidence: 95.0)
        )
      end

      before do
        allow(mock_textract_client).to receive(:analyze_document).and_return(textract_response)
      end

      it "returns ocr_complete status" do
        result = described_class.call(insurance)

        expect(result[:status]).to eq(:ocr_complete)
        expect(result[:data][:needs_review]).to be false
      end
    end

    context "with low confidence extraction" do
      let(:textract_response) do
        OpenStruct.new(
          document_metadata: OpenStruct.new(pages: 1),
          analyze_document_model_version: "1.0",
          blocks: build_textract_blocks(confidence: 70.0)
        )
      end

      before do
        allow(mock_textract_client).to receive(:analyze_document).and_return(textract_response)
      end

      it "returns ocr_needs_review status" do
        result = described_class.call(insurance)

        expect(result[:status]).to eq(:ocr_needs_review)
        expect(result[:data][:needs_review]).to be true
        expect(result[:data][:low_confidence_fields]).not_to be_empty
      end
    end

    context "with back image attached" do
      let(:insurance) { create(:insurance, :with_card_images) }

      let(:textract_response) do
        OpenStruct.new(
          document_metadata: OpenStruct.new(pages: 1),
          analyze_document_model_version: "1.0",
          blocks: build_textract_blocks
        )
      end

      before do
        allow(mock_textract_client).to receive(:analyze_document).and_return(textract_response)
      end

      it "analyzes both front and back images" do
        expect(mock_textract_client).to receive(:analyze_document).twice

        described_class.call(insurance)
      end
    end

    context "without back image" do
      it "analyzes only front image" do
        textract_response = OpenStruct.new(
          document_metadata: OpenStruct.new(pages: 1),
          analyze_document_model_version: "1.0",
          blocks: build_textract_blocks
        )

        expect(mock_textract_client).to receive(:analyze_document).once.and_return(textract_response)

        described_class.call(insurance)
      end
    end
  end

  describe "field mappings" do
    it "defines mappings for member_id" do
      expect(InsuranceServices::CardParser::FIELD_MAPPINGS[:member_id]).to include("Member ID", "Subscriber ID")
    end

    it "defines mappings for group_number" do
      expect(InsuranceServices::CardParser::FIELD_MAPPINGS[:group_number]).to include("Group", "Group#")
    end

    it "defines mappings for payer_name" do
      expect(InsuranceServices::CardParser::FIELD_MAPPINGS[:payer_name]).to include("Plan Name", "Insurance Company")
    end

    it "defines mappings for subscriber_name" do
      expect(InsuranceServices::CardParser::FIELD_MAPPINGS[:subscriber_name]).to include("Name", "Member Name")
    end
  end

  describe "MIN_CONFIDENCE threshold" do
    it "is set to 85%" do
      expect(InsuranceServices::CardParser::MIN_CONFIDENCE).to eq(85.0)
    end
  end

  private

  # Helper to build mock Textract blocks
  def build_textract_blocks(confidence: 90.0)
    key_block_id = "key-1"
    value_block_id = "value-1"
    word_block_id = "word-1"
    value_word_id = "value-word-1"

    [
      # KEY block
      OpenStruct.new(
        id: key_block_id,
        block_type: "KEY_VALUE_SET",
        entity_types: ["KEY"],
        confidence: confidence,
        relationships: [
          OpenStruct.new(type: "CHILD", ids: [word_block_id]),
          OpenStruct.new(type: "VALUE", ids: [value_block_id])
        ]
      ),
      # VALUE block
      OpenStruct.new(
        id: value_block_id,
        block_type: "KEY_VALUE_SET",
        entity_types: ["VALUE"],
        confidence: confidence,
        relationships: [
          OpenStruct.new(type: "CHILD", ids: [value_word_id])
        ]
      ),
      # WORD block for key text
      OpenStruct.new(
        id: word_block_id,
        block_type: "WORD",
        text: "Member ID",
        confidence: confidence
      ),
      # WORD block for value text
      OpenStruct.new(
        id: value_word_id,
        block_type: "WORD",
        text: "ABC123456789",
        confidence: confidence
      ),
      # LINE block for payer extraction
      OpenStruct.new(
        id: "line-1",
        block_type: "LINE",
        text: "Blue Cross Blue Shield",
        confidence: confidence,
        geometry: OpenStruct.new(
          bounding_box: OpenStruct.new(top: 0.1)
        )
      )
    ]
  end
end
