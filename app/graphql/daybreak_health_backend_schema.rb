# frozen_string_literal: true

# Ensure GraphQL error classes are loaded before schema initialization
require_relative "graphql_errors/error_codes"
require_relative "graphql_errors/base_error"

class DaybreakHealthBackendSchema < GraphQL::Schema
  mutation(Types::MutationType)
  query(Types::QueryType)
  subscription(Types::SubscriptionType)

  # For batch-loading (see https://graphql-ruby.org/dataloader/overview.html)
  use GraphQL::Dataloader

  # Enable subscriptions
  use GraphQL::Subscriptions::ActionCableSubscriptions

  # Custom error handling to format errors with standard structure
  rescue_from(StandardError) do |error, obj, args, context, field|
    handle_error(error, context, field)
  end

  # GraphQL-Ruby calls this when something goes wrong while running a query:
  def self.type_error(err, context)
    # if err.is_a?(GraphQL::InvalidNullError)
    #   # report to your bug tracker here
    #   return nil
    # end
    super
  end

  # Custom error handler that formats all errors consistently
  #
  # @param error [Exception] The error that occurred
  # @param context [GraphQL::Query::Context] GraphQL context
  # @param field [GraphQL::Schema::Field] Field where error occurred
  # @return [GraphQL::ExecutionError] Formatted error
  def self.handle_error(error, context, field)
    # Log the error (PHI-safe)
    Rails.logger.error("GraphQL Error: #{error.class.name} - #{error.message}")
    Rails.logger.error(error.backtrace.first(5).join("\n")) if error.backtrace

    case error
    when GraphQL::ExecutionError
      # Already a GraphQL error, add path if missing
      ensure_error_path(error, context)
      error
    when ActiveRecord::RecordNotFound
      # Convert ActiveRecord not found to GraphQL error
      GraphqlErrors::NotFoundError.new(
        'Resource not found',
        resource_type: error.model
      )
    when ActiveRecord::RecordInvalid
      # Convert validation errors
      GraphqlErrors::ValidationError.new(
        'Validation failed',
        errors: error.record.errors.to_hash
      )
    when Pundit::NotAuthorizedError
      # Convert authorization errors
      GraphqlErrors::ForbiddenError.new(
        'You do not have permission to perform this action'
      )
    else
      # Generic internal error (don't expose details)
      GraphqlErrors::InternalError.new
    end
  end

  # Ensure error has path in extensions
  #
  # @param error [GraphQL::ExecutionError] Error to modify
  # @param context [GraphQL::Query::Context] GraphQL context
  def self.ensure_error_path(error, context)
    if error.extensions && context.path
      error.extensions[:path] ||= context.path
    end
  end

  # Union and Interface Resolution
  def self.resolve_type(abstract_type, obj, ctx)
    # TODO: Implement this method
    # to return the correct GraphQL object type for `obj`
    raise(GraphQL::RequiredImplementationMissingError)
  end

  # Limit the size of incoming queries:
  max_query_string_tokens(5000)

  # Stop validating when it encounters this many errors:
  validate_max_errors(100)

  # Relay-style Object Identification:

  # Return a string UUID for `object`
  def self.id_from_object(object, type_definition, query_ctx)
    # For example, use Rails' GlobalID library (https://github.com/rails/globalid):
    object.to_gid_param
  end

  # Given a string UUID, find the object
  def self.object_from_id(global_id, query_ctx)
    # For example, use Rails' GlobalID library (https://github.com/rails/globalid):
    GlobalID.find(global_id)
  end
end
