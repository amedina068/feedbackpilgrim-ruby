require "test_helper"

class FeedbackPilgrim::ErrorsTest < FeedbackPilgrim::TestCase
  {
    400 => FeedbackPilgrim::ApiError,
    401 => FeedbackPilgrim::AuthenticationError,
    403 => FeedbackPilgrim::AuthorizationError,
    404 => FeedbackPilgrim::NotFoundError,
    405 => FeedbackPilgrim::MethodNotAllowedError,
    422 => FeedbackPilgrim::ValidationError,
    429 => FeedbackPilgrim::RateLimitError,
    500 => FeedbackPilgrim::ServerError,
    503 => FeedbackPilgrim::ServerError
  }.each do |status, error_class|
    define_method("test_status_#{status}_raises_#{error_class.name.split("::").last}") do
      stub_api(:get, "/posts/1").to_return(json({ message: "Nope." }, status:))

      error = assert_raises(error_class) { client(max_retries: 0).posts.find(1) }

      assert_equal status, error.status
      assert_equal "Nope.", error.message
      assert_kind_of FeedbackPilgrim::Error, error
    end
  end

  def test_an_unauthenticated_request
    stub_api(:get, "/posts").to_return(json({ message: "Unauthenticated." }, status: 401))

    assert_equal "Unauthenticated.", assert_raises(FeedbackPilgrim::AuthenticationError) { client.posts.list }.message
  end

  def test_an_authentication_error_with_an_error_field
    stub_api(:get, "/posts").to_return(json({ error: "Invalid API token" }, status: 401))

    error = assert_raises(FeedbackPilgrim::AuthenticationError) { client.posts.list }

    assert_equal "Invalid API token", error.message
    assert_equal({ "error" => "Invalid API token" }, error.body)
  end

  def test_not_found
    stub_api(:get, "/posts/999").to_return(json({ message: "No query results for model [App\\Models\\Post] 999" }, status: 404))

    error = assert_raises(FeedbackPilgrim::NotFoundError) { client.posts.find(999) }

    assert_equal "No query results for model [App\\Models\\Post] 999", error.message
  end

  def test_validation_error_carries_the_field_errors
    stub_api(:post, "/posts").to_return(json({
      message: "The title field is required.",
      errors: { title: [ "The title field is required." ] }
    }, status: 422))

    error = assert_raises(FeedbackPilgrim::ValidationError) { client.posts.create(title: "", content: "x") }

    assert_equal [ "The title field is required." ], error.errors["title"]
  end

  def test_validation_error_for_the_custom_fields
    stub_api(:post, "/contacts").to_return(json({
      message: "The metadata key [pilgrim_x] is reserved.",
      errors: { metadata: [ "The metadata key [pilgrim_x] is reserved." ] }
    }, status: 422))

    error = assert_raises(FeedbackPilgrim::ValidationError) do
      client.contacts.upsert(email: "jane@example.com", name: "Jane", custom_fields: { pilgrim_x: 1 })
    end

    assert_equal [ "The metadata key [pilgrim_x] is reserved." ], error.errors["metadata"]
  end

  def test_validation_error_without_field_errors
    stub_api(:post, "/tags").to_return(json({ message: "Invalid." }, status: 422))

    assert_equal({}, assert_raises(FeedbackPilgrim::ValidationError) { client.tags.create(title: "x") }.errors)
  end

  def test_rate_limit_error_carries_retry_after_in_seconds
    stub_api(:get, "/posts").to_return(json({ message: "Too Many Attempts." }, status: 429,
      headers: { "Retry-After" => "42", "X-RateLimit-Limit" => "120", "X-RateLimit-Remaining" => "0" }))

    error = assert_raises(FeedbackPilgrim::RateLimitError) { client(max_retries: 0).posts.list }

    assert_equal 42, error.retry_after
    assert_equal "Too Many Attempts.", error.message
  end

  def test_retry_after_as_an_http_date
    stub_api(:get, "/posts").to_return(json({}, status: 429, headers: { "Retry-After" => (Time.now + 30).httpdate }))

    assert_in_delta 30, assert_raises(FeedbackPilgrim::RateLimitError) { client(max_retries: 0).posts.list }.retry_after, 2
  end

  def test_a_rate_limit_without_retry_after
    stub_api(:get, "/posts").to_return(json({}, status: 429))

    assert_nil assert_raises(FeedbackPilgrim::RateLimitError) { client(max_retries: 0).posts.list }.retry_after
  end

  def test_a_body_that_is_not_json
    stub_api(:get, "/posts").to_return(status: 502, body: "<html>Bad Gateway</html>")

    error = assert_raises(FeedbackPilgrim::ServerError) { client(max_retries: 0).posts.list }

    assert_equal "Feedback Pilgrim returned HTTP 502", error.message
    assert_equal "<html>Bad Gateway</html>", error.body
  end

  def test_connection_error
    stub_api(:get, "/posts").to_raise(Errno::ECONNREFUSED)

    error = assert_raises(FeedbackPilgrim::ConnectionError) { client(max_retries: 0).posts.list }

    assert_kind_of Errno::ECONNREFUSED, error.cause
  end

  def test_timeout_is_a_connection_error
    stub_api(:get, "/posts").to_timeout

    assert_raises(FeedbackPilgrim::ConnectionError) { client(max_retries: 0).posts.list }
  end

  def test_tls_error_is_a_connection_error
    stub_api(:get, "/posts").to_raise(OpenSSL::SSL::SSLError)

    assert_raises(FeedbackPilgrim::ConnectionError) { client.posts.list }
  end
end
