require "json"
require "net/http"
require "openssl"
require "time"
require "uri"

require "feedbackpilgrim/version"
require "feedbackpilgrim/errors"
require "feedbackpilgrim/configuration"
require "feedbackpilgrim/record"
require "feedbackpilgrim/page"
require "feedbackpilgrim/identity"
require "feedbackpilgrim/webhook"
require "feedbackpilgrim/resource"
require "feedbackpilgrim/resources/posts"
require "feedbackpilgrim/resources/release_notes"
require "feedbackpilgrim/resources/contacts"
require "feedbackpilgrim/resources/testimonials"
require "feedbackpilgrim/resources/tags"
require "feedbackpilgrim/client"

# A client for one Feedback Pilgrim instance.
#
#   FeedbackPilgrim.configure do |config|
#     config.url   = "https://feedback.example.com"
#     config.token = "1|..."
#   end
#
#   FeedbackPilgrim.posts.create(title: "Add dark mode", content: "Please add a dark theme.")
#   FeedbackPilgrim.identity_hash(current_user.email)
module FeedbackPilgrim
  class << self
    def configure
      yield config
      reset!
    end

    def config
      @config ||= Configuration.new
    end

    def client
      @client ||= Client.new(**config.to_h)
    end

    def reset!
      @client = nil
    end

    def posts         = client.posts
    def release_notes = client.release_notes
    def contacts      = client.contacts
    def testimonials  = client.testimonials
    def tags          = client.tags

    def sign_in_url(...) = client.sign_in_url(...)

    # The user_hash of the widget for an email. Make it on the server only.
    #
    #   FeedbackPilgrim.identity_hash(current_user.email)
    def identity_hash(email, secret: config.identity_secret)
      Identity.digest(email, secret)
    end
  end
end

require "feedbackpilgrim/railtie" if defined?(Rails::Railtie)
