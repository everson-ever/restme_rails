# frozen_string_literal: true

module RestmeRails
  # Base error class for all RestmeRails custom exceptions.
  #
  # Inherit from this class when defining new domain-specific
  # exceptions inside the gem.
  #
  # Example:
  #
  #   raise RestmeRails::Error, "Generic failure"
  #
  class Error < StandardError; end

  # Raised when an authorization check fails during scope execution.
  #
  # Intended to signal that the current user or context
  # is not allowed to perform the requested action.
  #
  # Example:
  #
  #   raise RestmeRails::NotAuthorizedError, "You are not allowed to access this resource"
  #
  # This error can be rescued at the controller layer and mapped to:
  #
  #   HTTP 401 (Unauthorized)
  #   or
  #   HTTP 403 (Forbidden)
  #
  class NotAuthorizedError < Error; end

  # Raised when a record cannot be found during execution.
  #
  # Typically used when a resource lookup fails,
  # similar to ActiveRecord::RecordNotFound.
  #
  # Example:
  #
  #   raise RestmeRails::RecordNotFoundError, "Product not found"
  #
  # This error can be rescued and mapped to:
  #
  #   HTTP 404 (Not Found)
  #
  class RecordNotFoundError < Error; end
end
