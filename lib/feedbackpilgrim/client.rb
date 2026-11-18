module FeedbackPilgrim
  # A client for one Feedback Pilgrim instance. FeedbackPilgrim.client is the
  # default client, built from FeedbackPilgrim.config. Make your own to talk to
  # more than one instance:
  #
  #   client = FeedbackPilgrim::Client.new(url: "https://feedback.example.com", token: "1|...")
  #   client.posts.list
  class Client
    # The status and the parsed body of one response.
    Response = Data.define(:status, :body)

    # The request did not reach the server, so a retry cannot change data twice.
    BEFORE_SEND = [ Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError, Net::OpenTimeout ].freeze

    # The server possibly received the request.
    AFTER_SEND = [ Net::ReadTimeout, Net::WriteTimeout, Errno::ECONNRESET, Errno::EPIPE, Errno::ETIMEDOUT, EOFError ].freeze

    BASE_DELAY = 0.5
    MAX_DELAY = 8
    MAX_RETRY_AFTER = 60

    attr_reader :url, :timeout, :max_retries

    def initialize(url: nil, token: nil, timeout: 30, max_retries: 2)
      @url = url.to_s.chomp("/").delete_suffix("/api/public/v1")
      @token = token
      @timeout = timeout
      @max_retries = max_retries
    end

    def posts         = @posts ||= Posts.new(self)
    def release_notes = @release_notes ||= ReleaseNotes.new(self)
    def contacts      = @contacts ||= Contacts.new(self)
    def testimonials  = @testimonials ||= Testimonials.new(self)
    def tags          = @tags ||= Tags.new(self)

    # Creates or updates the contact with this email and returns a sign-in link
    # for the public site. The link is valid for 24 hours. Give it only to that contact.
    #
    #   redirect_to FeedbackPilgrim.sign_in_url(email: current_user.email, name: current_user.name)
    #
    # Each key of custom_fields becomes a custom field of the contact.
    def sign_in_url(email:, name: nil, mrr: nil, ltv: nil, avatar: nil, custom_fields: {})
      contact = { **custom_fields, email:, name:, mrr:, ltv:, avatar: }.compact
      body = request(:post, "/init", json: { contact: }).body

      # Without a contact email, the API returns [] instead of an object.
      body["auth_url"] if body.is_a?(Hash)
    end

    # Sends one request to {url}/api/public/v1{path} and returns a Response.
    #
    # Retries a 429 and a connection error that happened before the request
    # reached the server. Retries a 5xx and a later connection error only when
    # the request is idempotent. Each GET, PATCH and DELETE of the API is
    # idempotent. A POST is not, unless the caller says so.
    def request(method, path, query: nil, json: nil, idempotent: method != :post)
      attempt = 0

      begin
        attempt += 1
        response = transmit(method, path, query:, json:)
        raise ApiError.for(response) unless response.is_a?(Net::HTTPSuccess)

        Response.new(status: response.code.to_i, body: parse(response))
      rescue RateLimitError, ServerError => error
        raise unless attempt <= max_retries && retryable?(error, idempotent)

        pause delay(attempt, error.is_a?(RateLimitError) ? error.retry_after : nil)
        retry
      rescue *BEFORE_SEND, *AFTER_SEND => error
        unless attempt <= max_retries && (idempotent || BEFORE_SEND.any? { |kind| error.is_a?(kind) })
          raise ConnectionError, "Feedback Pilgrim request failed: #{error.message}"
        end

        pause delay(attempt)
        retry
      rescue OpenSSL::SSL::SSLError => error
        raise ConnectionError, "Feedback Pilgrim request failed: #{error.message}"
      end
    end

    def inspect
      "#<#{self.class.name} url=#{url.inspect}>"
    end

    private
      def transmit(method, path, query:, json:)
        raise ConfigurationError, "Set the Feedback Pilgrim url, for example https://feedback.example.com" if url.empty?
        raise ConfigurationError, "Set the Feedback Pilgrim token" if @token.to_s.empty?

        uri = URI("#{url}/api/public/v1#{path}")
        uri.query = URI.encode_www_form(query.compact) if query&.compact&.any?

        request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
        request["Authorization"] = "Bearer #{@token}"
        request["Accept"] = "application/json"
        request["User-Agent"] = "feedbackpilgrim-ruby/#{VERSION}"

        if json
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(json)
        end

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: timeout, read_timeout: timeout, write_timeout: timeout) do |http|
          http.request(request)
        end
      end

      # A 204 has no body.
      def parse(response)
        body = response.body.to_s.dup.force_encoding(Encoding::UTF_8)
        JSON.parse(body) unless body.empty?
      end

      def retryable?(error, idempotent)
        case error
        when RateLimitError then error.retry_after.nil? || error.retry_after <= MAX_RETRY_AFTER
        when ServerError    then idempotent
        end
      end

      # Exponential backoff with jitter. A Retry-After value wins.
      def delay(attempt, retry_after = nil)
        return retry_after if retry_after

        backoff = [ BASE_DELAY * (2**(attempt - 1)), MAX_DELAY ].min
        backoff / 2 + rand * backoff / 2
      end

      def pause(seconds)
        sleep seconds
      end
  end
end
