require "test_helper"

class FeedbackPilgrim::IdentityTest < FeedbackPilgrim::TestCase
  VECTORS = JSON.parse(File.read(File.expand_path("../fixtures/identity-hash-vectors.json", __dir__)))

  VECTORS["cases"].each do |vector|
    define_method("test_vector_#{vector["name"].gsub(/\W+/, "_")}") do
      assert_equal vector["normalized_email"].b, FeedbackPilgrim::Identity.normalize(vector["email"])
      assert_equal vector["user_hash"], FeedbackPilgrim.identity_hash(vector["email"], secret: VECTORS["identity_secret"])
    end
  end

  def test_trims_only_the_characters_of_php_trim
    assert_equal "\fjane@example.com", FeedbackPilgrim::Identity.normalize("\0\v\fJane@Example.com \r")
  end

  def test_the_secret_defaults_to_the_configuration
    FeedbackPilgrim.config.identity_secret = VECTORS["identity_secret"]

    assert_equal VECTORS["cases"].first["user_hash"], FeedbackPilgrim.identity_hash("jane@example.com")
  ensure
    FeedbackPilgrim.instance_variable_set(:@config, nil)
  end

  def test_a_missing_secret_is_a_configuration_error
    assert_raises(FeedbackPilgrim::ConfigurationError) { FeedbackPilgrim.identity_hash("jane@example.com", secret: nil) }
  end
end
