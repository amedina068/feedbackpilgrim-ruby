require "test_helper"

class FeedbackPilgrim::TagsTest < FeedbackPilgrim::TestCase
  def test_list
    stub_api(:get, "/tags", query: { search: "feat", sort_by: "created_at", sort_direction: "desc" })
      .to_return(paginator([ { id: 1, title: "feature", posts_count: 4, contacts_count: 2 } ], path: "/tags"))

    tag = client.tags.list(search: "feat", sort_by: "created_at", sort_direction: "desc").first

    assert_equal [ "feature", 4, 2 ], [ tag.title, tag.posts_count, tag.contacts_count ]
  end

  def test_create
    stub_api(:post, "/tags").with(body: { title: "feature" }).to_return(json({ id: 1, title: "feature" }, status: 201))

    assert_equal 1, client.tags.create(title: "feature").id
  end

  def test_update_uses_patch
    stub = stub_api(:patch, "/tags/1").with(body: { title: "enhancement" }).to_return(json(id: 1, title: "enhancement"))

    assert_equal "enhancement", client.tags.update(1, title: "enhancement").title
    assert_requested stub
  end

  def test_delete_returns_nil_for_a_204
    stub = stub_api(:delete, "/tags/1").to_return(status: 204, body: "")

    assert_nil client.tags.delete(1)
    assert_requested stub
  end

  def test_the_sdk_has_no_find_for_tags
    refute_respond_to client.tags, :find
  end
end
