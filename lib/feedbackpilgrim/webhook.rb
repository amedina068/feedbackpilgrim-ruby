module FeedbackPilgrim
  # Verifies a signed webhook delivery. Use it on the server only, because the
  # signing secret of the webhook is a secret.
  #
  #   event = FeedbackPilgrim::Webhook.verify(request.raw_post, request.headers)
  #   event.name          # => "post.status_changed"
  #   event.data.title    # => "Add dark mode"
  #   event.delivery_id   # => "0b6c4c1e-..."
  #
  # Give the raw body. A body that you parse and encode again has other bytes,
  # because the app escapes "/" as "\/" and each character that is not ASCII as \uXXXX.
  module Webhook
    EVENT     = "X-FeedbackPilgrim-Event"
    DELIVERY  = "X-FeedbackPilgrim-Delivery"
    TIMESTAMP = "X-FeedbackPilgrim-Timestamp"
    SIGNATURE = "X-FeedbackPilgrim-Signature-V2"

    # The seconds that a timestamp can be before or after the current time.
    TOLERANCE = 300

    # A verified delivery. Each retry of a delivery has the same delivery_id,
    # so store the IDs that you processed and drop a repeated delivery.
    Event = Data.define(:name, :data, :delivery_id, :timestamp)

    # True when the V2 signature matches the timestamp and the raw body, and the
    # timestamp is at most tolerance seconds from now.
    #
    #   FeedbackPilgrim::Webhook.valid?(body, signature: request.headers["X-FeedbackPilgrim-Signature-V2"],
    #     timestamp: request.headers["X-FeedbackPilgrim-Timestamp"])
    def self.valid?(body, signature:, timestamp:, secret: FeedbackPilgrim.config.webhook_secret, tolerance: TOLERANCE, now: Time.now)
      failure(body, signature:, timestamp:, secret:, tolerance:, now:).nil?
    end

    # Returns the Event. Raises WebhookVerificationError when the signature does
    # not match or the timestamp is too old or too new.
    #
    # headers can be the Rails request.headers, a Rack env or a Hash.
    def self.verify(body, headers, secret: FeedbackPilgrim.config.webhook_secret, tolerance: TOLERANCE, now: Time.now)
      timestamp = header(headers, TIMESTAMP)

      if (reason = failure(body, signature: header(headers, SIGNATURE), timestamp:, secret:, tolerance:, now:))
        raise WebhookVerificationError.new(reason)
      end

      payload = JSON.parse(body)
      Event.new(name: payload["event"], data: Record.wrap(payload["data"]),
                delivery_id: header(headers, DELIVERY), timestamp: Time.at(timestamp.to_i))
    end

    # The X-FeedbackPilgrim-Signature-V2 value for a timestamp and a raw body.
    def self.sign(timestamp, body, secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.".b + body.to_s.b)
    end

    # Returns :signature, :timestamp or nil. The signature comes first, so an
    # unsigned request learns nothing about the clock.
    def self.failure(body, signature:, timestamp:, secret:, tolerance:, now:)
      raise ConfigurationError, "Set the Feedback Pilgrim webhook secret to verify a webhook" if secret.to_s.empty?

      return :signature unless OpenSSL.secure_compare(sign(timestamp, body, secret), signature.to_s)
      :timestamp unless timestamp.to_s.match?(/\A\d+\z/) && (now.to_i - timestamp.to_i).abs <= tolerance
    end
    private_class_method :failure

    # Rails and Hash headers use the header name. A Rack env uses HTTP_X_FEEDBACKPILGRIM_TIMESTAMP.
    def self.header(headers, name)
      headers[name] || headers[name.downcase] || headers["HTTP_#{name.upcase.tr("-", "_")}"]
    end
    private_class_method :header
  end
end
