require "test_helper"

class FeedbackPilgrim::RetriesTest < FeedbackPilgrim::TestCase
  def test_retries_a_get_after_a_server_error
    stub = stub_api(:get, "/posts/1").to_return(json({}, status: 503)).then.to_return(json(id: 1, title: "A"))
    client = client()

    assert_equal "A", client.posts.find(1).title
    assert_requested stub, times: 2
    assert_equal 1, client.pauses.size
  end

  def test_stops_after_max_retries
    stub = stub_api(:get, "/posts/1").to_return(json({}, status: 500))

    assert_raises(FeedbackPilgrim::ServerError) { client(max_retries: 2).posts.find(1) }
    assert_requested stub, times: 3
  end

  def test_backoff_grows_and_has_jitter
    stub_api(:get, "/posts/1").to_return(json({}, status: 500))
    client = client(max_retries: 5)

    assert_raises(FeedbackPilgrim::ServerError) { client.posts.find(1) }

    client.pauses.zip([ 0.5, 1, 2, 4, 8 ]).each do |pause, backoff|
      assert_operator pause, :>=, backoff / 2.0
      assert_operator pause, :<=, backoff
    end
  end

  def test_retries_a_patch_and_a_delete_after_a_server_error
    patch = stub_api(:patch, "/posts/1").to_return(json({}, status: 502)).then.to_return(json(id: 1))
    delete = stub_api(:delete, "/tags/1").to_return(json({}, status: 502)).then.to_return(status: 204)

    client.posts.update(1, status: "completed")
    client.tags.delete(1)

    assert_requested patch, times: 2
    assert_requested delete, times: 2
  end

  def test_never_retries_a_post_after_a_server_error
    stub = stub_api(:post, "/posts").to_return(json({ message: "Server Error" }, status: 500))

    assert_raises(FeedbackPilgrim::ServerError) { client.posts.create(title: "A", content: "B") }
    assert_requested stub, times: 1
  end

  def test_retries_a_post_after_a_rate_limit_and_waits_for_retry_after
    stub = stub_api(:post, "/posts")
      .to_return(json({ message: "Too Many Attempts." }, status: 429, headers: { "Retry-After" => "7" }))
      .then.to_return(json({ id: 1 }, status: 201))
    client = client()

    assert_equal 1, client.posts.create(title: "A", content: "B").id
    assert_requested stub, times: 2
    assert_equal [ 7 ], client.pauses
  end

  def test_a_rate_limit_without_retry_after_uses_the_backoff
    stub_api(:get, "/posts").to_return(json({}, status: 429)).then.to_return(paginator([]))
    client = client()

    client.posts.list

    assert_operator client.pauses.first, :<=, 0.5
  end

  def test_does_not_wait_for_a_long_retry_after
    stub = stub_api(:get, "/posts").to_return(json({}, status: 429, headers: { "Retry-After" => "3600" }))

    error = assert_raises(FeedbackPilgrim::RateLimitError) { client.posts.list }

    assert_equal 3600, error.retry_after
    assert_requested stub, times: 1
  end

  def test_never_retries_a_post_after_a_refused_connection
    stub = stub_api(:post, "/tags").to_raise(Errno::ECONNREFUSED).then.to_return(json({ id: 1 }, status: 201))

    assert_raises(FeedbackPilgrim::ConnectionError) { client.tags.create(title: "feature") }
    assert_requested stub, times: 1
  end

  def test_retries_a_get_after_a_refused_connection_and_an_open_timeout
    stub = stub_api(:get, "/tags").to_raise(Errno::ECONNREFUSED).then.to_raise(Net::OpenTimeout).then.to_return(paginator([]))

    client.tags.list

    assert_requested stub, times: 3
  end

  def test_waits_for_retry_after_on_a_server_error
    stub_api(:get, "/posts").to_return(json({}, status: 503, headers: { "Retry-After" => "3" })).then.to_return(paginator([]))
    client = client()

    client.posts.list

    assert_equal [ 3 ], client.pauses
  end

  def test_ignores_a_retry_after_that_is_not_whole_seconds_or_a_date
    stub_api(:get, "/posts").to_return(json({}, status: 429, headers: { "Retry-After" => "-3" })).then.to_return(paginator([]))
    client = client()

    client.posts.list

    assert_operator client.pauses.first, :<=, 0.5
  end

  def test_never_retries_a_post_after_the_server_possibly_received_it
    stub = stub_api(:post, "/posts").to_raise(Net::ReadTimeout)

    assert_raises(FeedbackPilgrim::ConnectionError) { client.posts.create(title: "A", content: "B") }
    assert_requested stub, times: 1
  end

  def test_retries_a_get_after_a_read_timeout
    stub = stub_api(:get, "/tags").to_raise(Net::ReadTimeout).then.to_return(paginator([]))

    client.tags.list

    assert_requested stub, times: 2
  end

  def test_retries_a_contact_upsert_after_a_server_error
    stub = stub_api(:post, "/contacts").to_return(json({}, status: 500)).then.to_return(json({ id: 7 }, status: 201))

    assert_predicate client.contacts.upsert(email: "jane@example.com", name: "Jane"), :created?
    assert_requested stub, times: 2
  end

  def test_never_retries_a_client_error
    stub = stub_api(:get, "/posts/9").to_return(json({ message: "Not found." }, status: 404))

    assert_raises(FeedbackPilgrim::NotFoundError) { client.posts.find(9) }
    assert_requested stub, times: 1
  end

  def test_max_retries_zero_turns_retries_off
    stub = stub_api(:get, "/posts").to_return(json({}, status: 503))

    assert_raises(FeedbackPilgrim::ServerError) { client(max_retries: 0).posts.list }
    assert_requested stub, times: 1
  end
end
