module FeedbackPilgrim
  class Error < StandardError; end

  # A setting that the call needs is missing, for example the instance URL.
  class ConfigurationError < Error; end

  # The request did not get a response: the connection failed or timed out.
  class ConnectionError < Error; end

  # The API returned a status that is not a success.
  class ApiError < Error
    attr_reader :status, :body

    def self.for(response)
      class_for(response.code.to_i).new(response, parse(response.body))
    end

    def self.class_for(status)
      case status
      when 401 then AuthenticationError
      when 403 then AuthorizationError
      when 404 then NotFoundError
      when 405 then MethodNotAllowedError
      when 422 then ValidationError
      when 429 then RateLimitError
      when 500.. then ServerError
      else ApiError
      end
    end

    def self.parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      body
    end
    private_class_method :parse

    # Most errors have a message. The token check of the API returns an error field instead.
    def initialize(response, body)
      @status = response.code.to_i
      @body = body
      super(body.is_a?(Hash) && (body["message"] || body["error"]) || "Feedback Pilgrim returned HTTP #{status}")
    end
  end

  # A 401: the token is missing or wrong, or its user is deactivated.
  class AuthenticationError < ApiError; end

  # A 403. The REST API does not return it today.
  class AuthorizationError < ApiError; end

  class NotFoundError < ApiError; end

  # A 405: the API does not support the operation, for example the delete of a post.
  class MethodNotAllowedError < ApiError; end

  class ServerError < ApiError; end

  class ValidationError < ApiError
    # The field errors, for example { "title" => ["The title field is required."] }.
    def errors
      body.is_a?(Hash) && body["errors"] || {}
    end
  end

  # A 429. Each user can make 120 requests each minute, with all the tokens of the user.
  class RateLimitError < ApiError
    def initialize(response, body)
      @retry_after = response["Retry-After"]
      super
    end

    # The seconds to wait before the next request, from the Retry-After header.
    def retry_after
      return if @retry_after.nil?

      Integer(@retry_after, exception: false) || [ (Time.httpdate(@retry_after) - Time.now).ceil, 0 ].max
    rescue ArgumentError
      nil
    end
  end

  # The webhook delivery is not valid. reason is :signature or :timestamp.
  class WebhookVerificationError < Error
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason == :signature ? "The webhook signature does not match the body" : "The webhook timestamp is too old or too new")
    end
  end
end
