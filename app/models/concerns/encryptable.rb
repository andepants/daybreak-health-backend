# frozen_string_literal: true

module Encryptable
  extend ActiveSupport::Concern

  class_methods do
    def encrypts_phi(*attributes)
      attributes.each do |attr|
        encrypts attr, deterministic: false
      end
    end
  end
end
