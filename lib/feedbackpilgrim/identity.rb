module FeedbackPilgrim
  # The user_hash that proves the email of a signed-in user to the widget.
  # Make it on the server only. The identity secret must never reach a browser.
  module Identity
    # The characters that PHP trim() removes. Ruby strip also removes "\f".
    TRIM = /\A[ \t\n\r\0\v]+|[ \t\n\r\0\v]+\z/n

    def self.digest(email, secret)
      raise ConfigurationError, "Set the Feedback Pilgrim identity secret to make an identity hash" if secret.to_s.empty?

      OpenSSL::HMAC.hexdigest("SHA256", secret, normalize(email))
    end

    # The same as PHP strtolower(trim($email)): only the ASCII letters change case.
    def self.normalize(email)
      email.to_s.b.gsub(TRIM, "").tr("A-Z", "a-z")
    end
  end
end
