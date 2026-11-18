require_relative "lib/feedbackpilgrim/version"

Gem::Specification.new do |spec|
  spec.name        = "feedbackpilgrim"
  spec.version     = FeedbackPilgrim::VERSION
  spec.authors     = [ "Alejandro Medina" ]
  spec.summary     = "Ruby client and Rails integration for the Feedback Pilgrim API"
  spec.description = "Read and write the posts, release notes, contacts, testimonials and tags of a " \
                     "Feedback Pilgrim instance, make the widget identity hash, and verify webhooks. " \
                     "The gem uses the Ruby standard library only."
  spec.homepage    = "https://github.com/amedina068/feedbackpilgrim-ruby"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "sig/**/*", "README.md", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]
end
