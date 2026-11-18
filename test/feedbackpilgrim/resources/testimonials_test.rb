require "test_helper"

class FeedbackPilgrim::TestimonialsTest < FeedbackPilgrim::TestCase
  def test_list_approved
    stub = stub_api(:get, "/testimonials", query: { approved: "true", rating: "5", search: "roadmap" })
      .to_return(paginator([ { id: 1, rating: 5, approved_at: "2026-06-15T10:00:00.000000Z" } ], path: "/testimonials"))

    assert_equal [ 5 ], client.testimonials.list(approved: true, rating: 5, search: "roadmap").map(&:rating)
    assert_requested stub
  end

  def test_list_pending
    stub = stub_api(:get, "/testimonials", query: { approved: "false" }).to_return(paginator([]))

    client.testimonials.list(approved: false)

    assert_requested stub
  end

  def test_find
    stub_api(:get, "/testimonials/1").to_return(json(id: 1, username: "jane_doe"))

    assert_equal "jane_doe", client.testimonials.find(1).username
  end

  def test_create
    stub = stub_api(:post, "/testimonials")
      .with(body: { description: "The roadmap keeps our customers in the loop.", username: "jane_doe", rating: 5, contact_id: 42 })
      .to_return(json({ id: 1, approved_at: nil }, status: 201))

    testimonial = client.testimonials.create(description: "The roadmap keeps our customers in the loop.", username: "jane_doe", rating: 5, contact_id: 42)

    assert_nil testimonial.approved_at
    assert_requested stub
  end

  def test_update
    stub = stub_api(:patch, "/testimonials/1").with(body: { rating: 4, approved_at: "2026-06-15T10:00:00Z" }).to_return(json(id: 1, rating: 4))

    client.testimonials.update(1, rating: 4, approved_at: "2026-06-15T10:00:00Z")

    assert_requested stub
  end

  def test_approve_sends_the_time_as_iso8601
    stub = stub_api(:patch, "/testimonials/1").with(body: { approved_at: "2026-06-15T10:00:00Z" })
      .to_return(json(id: 1, approved_at: "2026-06-15T10:00:00.000000Z"))

    testimonial = client.testimonials.approve(1, at: Time.utc(2026, 6, 15, 10))

    assert_equal "2026-06-15T10:00:00.000000Z", testimonial.approved_at
    assert_requested stub
  end

  def test_approve_defaults_to_now
    stub = stub_api(:patch, "/testimonials/1").with { |request| Time.iso8601(JSON.parse(request.body)["approved_at"]) > Time.now - 60 }
      .to_return(json(id: 1))

    client.testimonials.approve(1)

    assert_requested stub
  end

  def test_the_sdk_has_no_delete_for_testimonials
    refute_respond_to client.testimonials, :delete
  end
end
