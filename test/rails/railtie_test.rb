require "rails_helper"

class FeedbackPilgrim::RailtieTest < ActiveSupport::TestCase
  test "reads the settings from the credentials" do
    assert_equal "https://feedback.example.com", FeedbackPilgrim.config.url
    assert_equal "1|credentials-token", FeedbackPilgrim.config.token
    assert_equal "credentials-identity-secret", FeedbackPilgrim.config.identity_secret
    assert_equal "credentials-webhook-secret", FeedbackPilgrim.config.webhook_secret
  end

  test "an initializer runs after the credentials and wins" do
    assert_equal 5, FeedbackPilgrim.config.timeout
    assert_equal 5, FeedbackPilgrim.client.timeout
  end

  test "the default client uses the credentials" do
    assert_equal "https://feedback.example.com", FeedbackPilgrim.client.url
  end

  test "the identity hash uses the secret of the credentials" do
    expected = OpenSSL::HMAC.hexdigest("SHA256", "credentials-identity-secret", "jane@example.com")

    assert_equal expected, FeedbackPilgrim.identity_hash(" Jane@Example.com ")
  end
end

class FeedbackPilgrim::WebhookControllerTest < ActionDispatch::IntegrationTest
  test "a controller verifies a delivery with request.raw_post and request.headers" do
    body = %({"event":"post.created","data":{"id":42,"title":"Export to CSV\\/Excel","content":"Caf\\u00e9","status":"pending","board_id":1,"contact_id":null,"stage":null}})

    post "/webhooks/feedbackpilgrim", params: body, headers: signed_headers(body)

    assert_response :success
    assert_equal "post.created d-42", response.body
  end

  test "a controller rejects a body that changed after signing" do
    body = %({"event":"post.created","data":{"id":42}})

    post "/webhooks/feedbackpilgrim", params: body.sub("42", "43"), headers: signed_headers(body)

    assert_response :bad_request
    assert_equal "signature", response.body
  end

  test "a controller rejects an old delivery" do
    body = %({"event":"post.created","data":{"id":42}})

    post "/webhooks/feedbackpilgrim", params: body, headers: signed_headers(body, timestamp: (Time.now.to_i - 301).to_s)

    assert_response :bad_request
    assert_equal "timestamp", response.body
  end

  private
    def signed_headers(body, timestamp: Time.now.to_i.to_s)
      {
        "Content-Type" => "application/json",
        "X-FeedbackPilgrim-Event" => "post.created",
        "X-FeedbackPilgrim-Delivery" => "d-42",
        "X-FeedbackPilgrim-Timestamp" => timestamp,
        "X-FeedbackPilgrim-Signature-V2" => FeedbackPilgrim::Webhook.sign(timestamp, body, "credentials-webhook-secret")
      }
    end
end
