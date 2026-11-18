module FeedbackPilgrim
  # The settings of the default client. Each value falls back to an environment
  # variable: FEEDBACKPILGRIM_URL, FEEDBACKPILGRIM_TOKEN, FEEDBACKPILGRIM_IDENTITY_SECRET
  # and FEEDBACKPILGRIM_WEBHOOK_SECRET. In a Rails app, the Railtie also reads
  # Rails.application.credentials.feedbackpilgrim.
  class Configuration
    attr_writer :url, :token, :identity_secret, :webhook_secret
    attr_accessor :timeout, :max_retries

    def initialize
      @timeout = 30
      @max_retries = 2
    end

    def url             = @url || ENV["FEEDBACKPILGRIM_URL"]
    def token           = @token || ENV["FEEDBACKPILGRIM_TOKEN"]
    def identity_secret = @identity_secret || ENV["FEEDBACKPILGRIM_IDENTITY_SECRET"]
    def webhook_secret  = @webhook_secret || ENV["FEEDBACKPILGRIM_WEBHOOK_SECRET"]

    # Copies the known keys of a Hash, for example the feedbackpilgrim credentials.
    def merge!(settings)
      settings.to_h.each do |key, value|
        public_send("#{key}=", value) if respond_to?("#{key}=")
      end
      self
    end

    # The settings of a client. The two secrets are not part of them.
    def to_h
      { url:, token:, timeout:, max_retries: }
    end

    def inspect
      "#<#{self.class.name} url=#{url.inspect} timeout=#{timeout} max_retries=#{max_retries}>"
    end
  end
end
