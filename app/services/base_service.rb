# Base service class for business logic
# All service objects should inherit from this class
#
# Example usage:
#   class UserService < BaseService
#     def initialize(user)
#       @user = user
#     end
#
#     def call
#       # Business logic here
#     end
#   end
class BaseService
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end
end
