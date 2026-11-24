module FeedbackPilgrim
  class Error < StandardError; end

  # A setting that the call needs is missing, for example the instance URL.
  class ConfigurationError < Error; end

  # The request did not get a response: the connection failed or timed out.
  # before_send? is true for a DNS failure, a refused connection or a connect
  # timeout. Then the server did not get the request, so a retry is safe.
  class ConnectionError < Error
    def initialize(message = nil, before_send: false)
      @before_send = before_send
      super(message)
    end

    def before_send? = @before_send
  end

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
      @retry_after = response["Retry-After"]
      super(body.is_a?(Hash) && (body["message"] || body["error"]) || "Feedback Pilgrim returned HTTP #{status}")
    end

    # The seconds to wait before the next request, from the Retry-After header:
    # whole seconds or an HTTP date. nil when the header is missing or has another value.
    def retry_after
      value = @retry_after.to_s.strip
      return value.to_i if value.match?(/\A[0-9]+\z/)

      [ (Time.httpdate(value) - Time.now).ceil, 0 ].max
    rescue ArgumentError
      nil
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
  class RateLimitError < ApiError; end

  # The webhook delivery is not valid. reason is :timestamp, :signature or :payload.
  class WebhookVerificationError < Error
    MESSAGES = {
      timestamp: "The webhook timestamp is missing, is not a Unix time, or is outside the tolerance",
      signature: "The webhook signature is missing or does not match the body",
      payload: "The webhook body is not a JSON object"
    }.freeze

    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(MESSAGES.fetch(reason))
    end
  end
end
