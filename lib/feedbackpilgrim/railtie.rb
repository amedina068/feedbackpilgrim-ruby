module FeedbackPilgrim
  # Reads Rails.application.credentials.feedbackpilgrim.
  #
  #   # bin/rails credentials:edit
  #   feedbackpilgrim:
  #     url: https://feedback.example.com
  #     token: 1|...
  #     identity_secret: ...
  #     webhook_secret: ...
  #
  # An initializer that calls FeedbackPilgrim.configure runs later and wins.
  class Railtie < Rails::Railtie
    initializer "feedbackpilgrim.credentials", before: :load_config_initializers do |app|
      if (credentials = app.credentials.feedbackpilgrim)
        FeedbackPilgrim.config.merge!(credentials)
        FeedbackPilgrim.reset!
      end
    end
  end
end
