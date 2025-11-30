# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::Client do
  let(:messages) do
    [
      { role: "system", content: "You are a helpful assistant" },
      { role: "user", content: "Hello" }
    ]
  end

  # Set dummy API keys for tests
  before do
    ENV["ANTHROPIC_API_KEY"] = "test_anthropic_key"
    ENV["OPENAI_API_KEY"] = "test_openai_key"
  end

  after do
    ENV.delete("ANTHROPIC_API_KEY")
    ENV.delete("OPENAI_API_KEY")
  end

  describe "#initialize" do
    it "initializes with default provider" do
      client = described_class.new
      expect(client.provider_name).to eq(:anthropic)
    end

    it "initializes with specified provider" do
      client = described_class.new(provider: :openai)
      expect(client.provider_name).to eq(:openai)
    end

    it "raises error for unsupported provider" do
      expect {
        described_class.new(provider: :invalid)
      }.to raise_error(ArgumentError, /Unsupported provider/)
    end

    context "with AI_PROVIDER environment variable" do
      before { ENV["AI_PROVIDER"] = "openai" }
      after { ENV.delete("AI_PROVIDER") }

      it "uses configured provider" do
        client = described_class.new
        expect(client.provider_name).to eq(:openai)
      end
    end
  end

  describe "#chat" do
    let(:client) { described_class.new }
    let(:mock_provider) { instance_double(Ai::Providers::AnthropicProvider) }

    before do
      allow(Ai::Providers::AnthropicProvider).to receive(:new).and_return(mock_provider)
    end

    it "validates messages array" do
      expect {
        client.chat(messages: "not an array", context: {})
      }.to raise_error(ArgumentError, /must be an array/)
    end

    it "validates messages are not empty" do
      expect {
        client.chat(messages: [], context: {})
      }.to raise_error(ArgumentError, /cannot be empty/)
    end

    it "validates message format" do
      invalid_messages = [{ invalid: "format" }]
      expect {
        client.chat(messages: invalid_messages, context: {})
      }.to raise_error(ArgumentError, /must have :role and :content/)
    end

    it "validates message roles" do
      invalid_messages = [{ role: "invalid", content: "test" }]
      expect {
        client.chat(messages: invalid_messages, context: {})
      }.to raise_error(ArgumentError, /invalid role/)
    end

    it "delegates to provider" do
      response = { content: "Hello!", role: "assistant" }
      expect(mock_provider).to receive(:chat).with(messages: messages, context: {}).and_return(response)

      result = client.chat(messages: messages, context: {})
      expect(result).to eq(response)
    end

    it "handles rate limit errors" do
      allow(mock_provider).to receive(:chat).and_raise(Ai::Providers::BaseProvider::RateLimitError)

      expect {
        client.chat(messages: messages, context: {})
      }.to raise_error(Ai::Providers::BaseProvider::RateLimitError)
    end

    it "handles authentication errors" do
      allow(mock_provider).to receive(:chat).and_raise(Ai::Providers::BaseProvider::AuthenticationError)

      expect {
        client.chat(messages: messages, context: {})
      }.to raise_error(Ai::Providers::BaseProvider::AuthenticationError)
    end

    it "handles API errors" do
      allow(mock_provider).to receive(:chat).and_raise(Ai::Providers::BaseProvider::ApiError)

      expect {
        client.chat(messages: messages, context: {})
      }.to raise_error(Ai::Providers::BaseProvider::ApiError)
    end
  end

  describe "#stream" do
    let(:client) { described_class.new }
    let(:mock_provider) { instance_double(Ai::Providers::AnthropicProvider) }

    before do
      allow(Ai::Providers::AnthropicProvider).to receive(:new).and_return(mock_provider)
    end

    it "validates messages before streaming" do
      expect {
        client.stream(messages: [], context: {})
      }.to raise_error(ArgumentError, /cannot be empty/)
    end

    it "delegates to provider with block" do
      chunks = []
      response = { content: "Full response", role: "assistant" }

      # Mock the stream method to call the provided block
      allow(mock_provider).to receive(:stream).and_yield("Hello").and_yield(" there!").and_return(response)

      result = client.stream(messages: messages, context: {}) do |chunk|
        chunks << chunk
      end

      expect(chunks).to eq(["Hello", " there!"])
      expect(result).to eq(response)
    end
  end

  describe "performance" do
    let(:client) { described_class.new }
    let(:mock_provider) { instance_double(Ai::Providers::AnthropicProvider) }

    before do
      allow(Ai::Providers::AnthropicProvider).to receive(:new).and_return(mock_provider)
      allow(mock_provider).to receive(:chat).and_return({ content: "Response", role: "assistant" })
    end

    it "completes chat requests quickly" do
      # AC6: AI response time p95 < 2 seconds
      # This is a baseline test - actual performance depends on AI provider
      times = []

      10.times do
        start_time = Time.current
        client.chat(messages: messages, context: {})
        times << (Time.current - start_time)
      end

      # With mocked provider, should be very fast
      p95 = times.sort[9] # 95th percentile of 10 samples
      expect(p95).to be < 0.1 # Mocked should be < 100ms
    end
  end
end
