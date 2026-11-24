require "test_helper"

class FeedbackPilgrim::WebhookTest < FeedbackPilgrim::TestCase
  VECTORS = JSON.parse(File.read(File.expand_path("../fixtures/webhook-signature-vectors.json", __dir__)))
  LEGACY = JSON.parse(File.read(File.expand_path("../fixtures/webhook-signature-vectors-legacy.json", __dir__)))
  SHARED = JSON.parse(File.read(File.expand_path("../fixtures/webhook-verify-vectors.json", __dir__)))
  SECRET = VECTORS["secret"]

  SHARED["cases"].each do |vector|
    define_method("test_shared_#{vector["name"].gsub(/\W+/, "_")}") do
      expect = vector["expect"]
      verify = -> { FeedbackPilgrim::Webhook.verify(vector["body"], vector["headers"], secret: SHARED["secret"], now: vector["now"]) }

      if expect["valid"]
        event = verify.call
        assert_equal expect["type"], event.type
        assert_equal expect["timestamp"], event.timestamp
        expect["delivery_id"] ? assert_equal(expect["delivery_id"], event.delivery_id) : assert_nil(event.delivery_id)
        assert_equal expect["data_id"], event.data.id
        assert_equal JSON.parse(vector["body"]), event.payload
      else
        assert_equal expect["reason"].to_sym, assert_raises(FeedbackPilgrim::WebhookVerificationError) { verify.call }.reason
      end
    end
  end

  VECTORS["cases"].each do |vector|
    define_method("test_vector_#{vector["name"].gsub(/\W+/, "_")}") do
      now = vector["timestamp"].to_i
      headers = {
        "X-FeedbackPilgrim-Event" => vector["event"], "X-FeedbackPilgrim-Delivery" => "d-1",
        "X-FeedbackPilgrim-Timestamp" => vector["timestamp"], "X-FeedbackPilgrim-Signature-V2" => vector["signature"]
      }

      assert_equal vector["valid"], FeedbackPilgrim::Webhook.valid?(vector["body"], signature: vector["signature"], timestamp: vector["timestamp"], secret: SECRET, now:)

      if vector["valid"]
        event = FeedbackPilgrim::Webhook.verify(vector["body"], headers, secret: SECRET, now:)
        assert_equal vector["event"], event.type
        assert_equal JSON.parse(vector["body"])["data"], event.data.to_h
      else
        error = assert_raises(FeedbackPilgrim::WebhookVerificationError) { FeedbackPilgrim::Webhook.verify(vector["body"], headers, secret: SECRET, now:) }
        assert_equal :signature, error.reason
      end
    end
  end

  def test_the_vectors_use_the_default_tolerance_and_header_names
    assert_equal VECTORS["tolerance_seconds"], FeedbackPilgrim::Webhook::TOLERANCE
    assert_equal VECTORS["signature_header"], FeedbackPilgrim::Webhook::SIGNATURE
    assert_equal VECTORS["timestamp_header"], FeedbackPilgrim::Webhook::TIMESTAMP
    assert_equal VECTORS["delivery_header"], FeedbackPilgrim::Webhook::DELIVERY
    assert_equal VECTORS["event_header"], FeedbackPilgrim::Webhook::EVENT
  end

  def test_sign_makes_the_vector_signatures
    VECTORS["cases"].select { |vector| vector["valid"] }.each do |vector|
      assert_equal vector["signature"], FeedbackPilgrim::Webhook.sign(vector["timestamp"], vector["body"], SECRET)
    end
  end

  def test_rejects_the_deprecated_body_only_signature
    LEGACY["cases"].each do |vector|
      refute FeedbackPilgrim::Webhook.valid?(vector["body"], signature: vector["signature"], timestamp: "1763456789", secret: SECRET, now: 1763456789)
    end
  end

  def test_gives_the_delivery_id_and_the_timestamp
    event = verify(delivery("post.created", timestamp: 1_000, delivery: "0b6c4c1e-8b4a-4f8e-9d55-3a1f0c2e7d10"), now: 1_000)

    assert_equal "0b6c4c1e-8b4a-4f8e-9d55-3a1f0c2e7d10", event.delivery_id
    assert_equal 1_000, event.timestamp
    assert_equal 42, event.data.id
  end

  def test_accepts_a_timestamp_at_the_edge_of_the_tolerance
    body, headers = delivery("post.created", timestamp: 1_000)

    assert verify([ body, headers ], now: 1_300)
    assert verify([ body, headers ], now: 700)
  end

  def test_rejects_an_old_timestamp
    body, headers = delivery("post.created", timestamp: 1_000)

    error = assert_raises(FeedbackPilgrim::WebhookVerificationError) { verify([ body, headers ], now: 1_301) }
    assert_equal :timestamp, error.reason
    refute FeedbackPilgrim::Webhook.valid?(body, signature: headers[FeedbackPilgrim::Webhook::SIGNATURE], timestamp: 1_000, secret: SECRET, now: 1_301)
  end

  def test_rejects_a_timestamp_in_the_future
    body, headers = delivery("post.created", timestamp: 2_000)

    assert_equal :timestamp, assert_raises(FeedbackPilgrim::WebhookVerificationError) { verify([ body, headers ], now: 1_000) }.reason
  end

  def test_the_tolerance_is_a_parameter
    body, headers = delivery("post.created", timestamp: 1_000)

    assert verify([ body, headers ], tolerance: 600, now: 1_500)
    assert_raises(FeedbackPilgrim::WebhookVerificationError) { verify([ body, headers ], tolerance: 60, now: 1_100) }
  end

  def test_now_can_be_a_time
    body, headers = delivery("post.created", timestamp: 1_000)

    assert verify([ body, headers ], now: Time.at(1_100))
  end

  def test_reads_rack_env_headers
    body, headers = delivery("post.created")
    env = headers.to_h { |name, value| [ "HTTP_#{name.upcase.tr("-", "_")}", value ] }

    assert_equal "d-1", FeedbackPilgrim::Webhook.verify(body, env, secret: SECRET).delivery_id
  end

  def test_reads_lowercase_headers
    body, headers = delivery("post.created")

    assert FeedbackPilgrim::Webhook.verify(body, headers.transform_keys(&:downcase), secret: SECRET)
  end

  def test_missing_headers_fail_on_the_timestamp
    error = assert_raises(FeedbackPilgrim::WebhookVerificationError) { FeedbackPilgrim::Webhook.verify("{}", {}, secret: SECRET) }

    assert_equal :timestamp, error.reason
    refute FeedbackPilgrim::Webhook.valid?("{}", signature: nil, timestamp: nil, secret: SECRET)
  end

  def test_an_uppercase_signature_is_valid
    body, headers = delivery("post.created", timestamp: 1_000)

    assert FeedbackPilgrim::Webhook.valid?(body, signature: " #{headers[FeedbackPilgrim::Webhook::SIGNATURE].upcase} ", timestamp: "1000", secret: SECRET, now: 1_000)
  end

  def test_a_timestamp_that_is_not_a_number_fails_on_the_timestamp
    body = %({"event":"post.created","data":{}})
    headers = { "X-FeedbackPilgrim-Timestamp" => "soon", "X-FeedbackPilgrim-Signature-V2" => FeedbackPilgrim::Webhook.sign("soon", body, SECRET) }

    assert_equal :timestamp, assert_raises(FeedbackPilgrim::WebhookVerificationError) { FeedbackPilgrim::Webhook.verify(body, headers, secret: SECRET) }.reason
  end

  def test_a_binary_body_with_utf8_bytes
    body = %({"event":"post.created","data":{"title":"Café"}}).b
    timestamp = Time.now.to_i.to_s
    headers = { "X-FeedbackPilgrim-Timestamp" => timestamp, "X-FeedbackPilgrim-Signature-V2" => FeedbackPilgrim::Webhook.sign(timestamp, body, SECRET) }

    assert_equal "Café", FeedbackPilgrim::Webhook.verify(body, headers, secret: SECRET).data.title
  end

  def test_the_secret_defaults_to_the_configuration
    FeedbackPilgrim.config.webhook_secret = SECRET

    assert FeedbackPilgrim::Webhook.verify(*delivery("post.completed"))
  ensure
    FeedbackPilgrim.instance_variable_set(:@config, nil)
  end

  def test_a_missing_secret_is_a_configuration_error
    assert_raises(FeedbackPilgrim::ConfigurationError) { FeedbackPilgrim::Webhook.verify(*delivery("post.created"), secret: nil) }
    assert_raises(FeedbackPilgrim::ConfigurationError) { FeedbackPilgrim::Webhook.valid?("{}", signature: "x", timestamp: "1", secret: "") }
  end

  private
    def delivery(event, timestamp: Time.now.to_i, delivery: "d-1")
      body = JSON.generate(event:, data: { id: 42, title: "Add dark mode", content: "Please.", status: "pending", board_id: 1, contact_id: nil, stage: nil })
      headers = {
        "X-FeedbackPilgrim-Event" => event, "X-FeedbackPilgrim-Delivery" => delivery,
        "X-FeedbackPilgrim-Timestamp" => timestamp.to_s, "X-FeedbackPilgrim-Signature-V2" => FeedbackPilgrim::Webhook.sign(timestamp, body, SECRET)
      }
      [ body, headers ]
    end

    def verify((body, headers), **options)
      FeedbackPilgrim::Webhook.verify(body, headers, secret: SECRET, **options)
    end
end
