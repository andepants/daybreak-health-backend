# frozen_string_literal: true

# AWS SDK configuration for Textract and S3 services
#
# Required environment variables:
#   - AWS_ACCESS_KEY_ID: AWS access key
#   - AWS_SECRET_ACCESS_KEY: AWS secret key
#   - AWS_REGION: AWS region (defaults to 'us-east-1')
#   - S3_BUCKET: S3 bucket name for Active Storage
#
# Required IAM permissions:
#   - textract:AnalyzeDocument
#   - s3:GetObject (for Textract to read images from S3)
#
# @see Story 4.2: OCR Insurance Card Extraction

Aws.config.update({
  region: ENV.fetch("AWS_REGION", "us-east-1"),
  credentials: Aws::Credentials.new(
    ENV["AWS_ACCESS_KEY_ID"],
    ENV["AWS_SECRET_ACCESS_KEY"]
  )
})

# Textract client singleton for OCR processing
# Lazily initialized to avoid issues in test environments
module AwsClients
  class << self
    def textract
      @textract ||= Aws::Textract::Client.new
    end

    def reset!
      @textract = nil
    end
  end
end
