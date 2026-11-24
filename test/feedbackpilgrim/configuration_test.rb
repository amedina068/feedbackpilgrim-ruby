require "test_helper"

class FeedbackPilgrim::ConfigurationTest < FeedbackPilgrim::TestCase
  VARIABLES = %w[ FEEDBACKPILGRIM_URL FEEDBACKPILGRIM_TOKEN FEEDBACKPILGRIM_IDENTITY_SECRET FEEDBACKPILGRIM_WEBHOOK_SECRET ].freeze

  def setup
    super
    @saved = VARIABLES.to_h { |name| [ name, ENV.delete(name) ] }
  end

  def teardown
    @saved.each { |name, value| value ? ENV[name] = value : ENV.delete(name) }
    super
  end

  def test_defaults
    config = FeedbackPilgrim::Configuration.new

    assert_nil config.url
    assert_nil config.token
    assert_equal 30, config.timeout
    assert_equal 2, config.max_retries
  end

  def test_reads_the_environment
    ENV["FEEDBACKPILGRIM_URL"] = URL
    ENV["FEEDBACKPILGRIM_TOKEN"] = TOKEN
    ENV["FEEDBACKPILGRIM_IDENTITY_SECRET"] = "identity"
    ENV["FEEDBACKPILGRIM_WEBHOOK_SECRET"] = "webhook"
    config = FeedbackPilgrim::Configuration.new

    assert_equal [ URL, TOKEN, "identity", "webhook" ], [ config.url, config.token, config.identity_secret, config.webhook_secret ]
  end

  def test_a_setting_wins_over_the_environment
    ENV["FEEDBACKPILGRIM_URL"] = "https://env.example.com"
    config = FeedbackPilgrim::Configuration.new
    config.url = URL

    assert_equal URL, config.url
  end

  def test_merge_copies_the_known_keys
    config = FeedbackPilgrim::Configuration.new.merge!(url: URL, "token" => TOKEN, timeout: 5, unknown: "x")

    assert_equal URL, config.url
    assert_equal TOKEN, config.token
    assert_equal 5, config.timeout
  end

  def test_to_h_leaves_out_the_secrets
    config = FeedbackPilgrim::Configuration.new.merge!(url: URL, token: TOKEN, identity_secret: "i", webhook_secret: "w")

    assert_equal({ url: URL, token: TOKEN, timeout: 30, max_retries: 2 }, config.to_h)
  end

  def test_inspect_hides_the_token_and_the_secrets
    config = FeedbackPilgrim::Configuration.new.merge!(url: URL, token: TOKEN, identity_secret: "identity-x", webhook_secret: "webhook-x")

    [ TOKEN, "identity-x", "webhook-x" ].each { |secret| refute_includes config.inspect, secret }
  end
end
