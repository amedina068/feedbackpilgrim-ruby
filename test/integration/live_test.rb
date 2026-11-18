$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "feedbackpilgrim"
require "minitest/autorun"

# Talks to a real Feedback Pilgrim instance. The tests only read.
#
#   FEEDBACKPILGRIM_TEST_URL=https://feedback.example.com FEEDBACKPILGRIM_TEST_TOKEN=... bin/rake test:integration
class FeedbackPilgrim::LiveTest < Minitest::Test
  def setup
    unless ENV["FEEDBACKPILGRIM_TEST_URL"] && ENV["FEEDBACKPILGRIM_TEST_TOKEN"]
      skip "Set FEEDBACKPILGRIM_TEST_URL and FEEDBACKPILGRIM_TEST_TOKEN to run the integration tests"
    end

    @client = FeedbackPilgrim::Client.new(url: ENV["FEEDBACKPILGRIM_TEST_URL"], token: ENV["FEEDBACKPILGRIM_TEST_TOKEN"])
  end

  def test_list_posts
    page = @client.posts.list(per_page: 5)

    assert_kind_of Array, page.records
    assert_operator page.meta.per_page, :<=, 5
    page.each { |post| assert_kind_of Integer, post.id }
  end

  def test_list_tags
    page = @client.tags.list(per_page: 5)

    assert_kind_of Array, page.records
    page.each { |tag| assert_kind_of String, tag.title }
  end
end
