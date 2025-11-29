# frozen_string_literal: true

# Explicitly require GraphQL modules that don't follow standard Rails autoload paths
# These modules use namespaces that don't match their directory structure

require_relative '../../app/graphql/errors/error_codes'
require_relative '../../app/graphql/errors/base_error'
require_relative '../../app/graphql/concerns/current_session'
