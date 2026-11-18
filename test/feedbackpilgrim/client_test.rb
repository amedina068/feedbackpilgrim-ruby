require "test_helper"

class FeedbackPilgrim::ClientTest < FeedbackPilgrim::TestCase
  def test_sends_the_token_and_accept_header
    stub = stub_api(:get, "/tags")
      .with(headers: { "Authorization" => "Bearer #{TOKEN}", "Accept" => "application/json", "User-Agent" => "feedbackpilgrim-ruby/#{FeedbackPilgrim::VERSION}" })
      .to_return(paginator([]))

    client.tags.list

    assert_requested stub
  end

  def test_sends_json_with_a_content_type
    stub = stub_api(:post, "/tags").with(body: { title: "feature" }, headers: { "Content-Type" => "application/json" })
      .to_return(json({ id: 1, title: "feature" }, status: 201))

    client.tags.create(title: "feature")

    assert_requested stub
  end

  def test_the_url_can_end_with_a_slash_or_the_api_path
    [ "#{URL}/", "#{URL}/api/public/v1", "#{URL}/api/public/v1/" ].each do |url|
      assert_equal URL, FeedbackPilgrim::Client.new(url:, token: TOKEN).url
    end
  end

  def test_an_instance_in_a_subfolder
    stub = stub_request(:get, "https://example.com/feedback/api/public/v1/tags").to_return(paginator([]))

    FeedbackPilgrim::Client.new(url: "https://example.com/feedback", token: TOKEN).tags.list

    assert_requested stub
  end

  def test_a_missing_url_is_a_configuration_error
    error = assert_raises(FeedbackPilgrim::ConfigurationError) { FeedbackPilgrim::Client.new(token: TOKEN).tags.list }

    assert_match "url", error.message
  end

  def test_a_missing_token_is_a_configuration_error
    error = assert_raises(FeedbackPilgrim::ConfigurationError) { FeedbackPilgrim::Client.new(url: URL).tags.list }

    assert_match "token", error.message
  end

  def test_inspect_hides_the_token
    refute_includes client.inspect, TOKEN
  end

  def test_sign_in_url
    stub = stub_api(:post, "/init")
      .with(body: { contact: { plan: "pro", email: "jane@example.com", name: "Jane Doe", mrr: 99.99 } })
      .to_return(json(auth_url: "https://acme.example.com/authenticate/550e8400?expires=1&signature=abc"))

    url = client.sign_in_url(email: "jane@example.com", name: "Jane Doe", mrr: 99.99, custom_fields: { plan: "pro" })

    assert_equal "https://acme.example.com/authenticate/550e8400?expires=1&signature=abc", url
    assert_requested stub
  end

  def test_sign_in_url_is_nil_when_the_api_returns_an_empty_array
    stub_api(:post, "/init").to_return(json([]))

    assert_nil client.sign_in_url(email: "")
  end

  def test_sign_in_url_is_not_retried_after_a_server_error
    stub = stub_api(:post, "/init").to_return(json({ message: "Server Error" }, status: 500))

    assert_raises(FeedbackPilgrim::ServerError) { client.sign_in_url(email: "jane@example.com") }
    assert_requested stub, times: 1
  end

  def test_the_module_uses_the_default_client
    FeedbackPilgrim.configure do |config|
      config.url = URL
      config.token = TOKEN
    end
    stub_api(:post, "/init").to_return(json(auth_url: "https://acme.example.com/authenticate/1"))

    assert_equal "https://acme.example.com/authenticate/1", FeedbackPilgrim.sign_in_url(email: "jane@example.com")
    assert_same FeedbackPilgrim.client.posts, FeedbackPilgrim.posts
  ensure
    FeedbackPilgrim.instance_variable_set(:@config, nil)
    FeedbackPilgrim.reset!
  end

  def test_configure_resets_the_default_client
    FeedbackPilgrim.configure { |config| config.url = URL }
    first = FeedbackPilgrim.client
    FeedbackPilgrim.configure { |config| config.timeout = 5 }

    refute_same first, FeedbackPilgrim.client
    assert_equal 5, FeedbackPilgrim.client.timeout
  ensure
    FeedbackPilgrim.instance_variable_set(:@config, nil)
    FeedbackPilgrim.reset!
  end
end
