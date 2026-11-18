require "rails/generators/base"

module FeedbackPilgrim
  module Generators
    # bin/rails generate feedbackpilgrim:install
    class InstallGenerator < Rails::Generators::Base
      # The class name gives "feedback_pilgrim:install". The gem is feedbackpilgrim.
      namespace "feedbackpilgrim:install"
      source_root File.expand_path("templates", __dir__)

      desc "Writes config/initializers/feedbackpilgrim.rb"

      def copy_initializer
        template "feedbackpilgrim.rb", "config/initializers/feedbackpilgrim.rb"
      end

      def show_credentials
        say <<~TEXT

          Add the settings of your Feedback Pilgrim instance to the credentials:

            bin/rails credentials:edit

            feedbackpilgrim:
              url: https://feedback.example.com
              token: your-api-token
              identity_secret: your-identity-secret
              webhook_secret: your-webhook-signing-secret

        TEXT
      end
    end
  end
end
