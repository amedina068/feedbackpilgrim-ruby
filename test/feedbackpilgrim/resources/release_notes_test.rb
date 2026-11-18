require "test_helper"

class FeedbackPilgrim::ReleaseNotesTest < FeedbackPilgrim::TestCase
  def test_list_with_filters
    stub = stub_api(:get, "/release-notes", query: { search: "2.1", published: "true", tag: "feature", sort_by: "published_at", sort_direction: "desc" })
      .to_return(paginator([ { id: 1, title: "Version 2.1.0", votes: [], comments: [] } ], path: "/release-notes"))

    page = client.release_notes.list(search: "2.1", published: true, tag: "feature", sort_by: "published_at", sort_direction: "desc")

    assert_equal [ "Version 2.1.0" ], page.map(&:title)
    assert_requested stub
  end

  def test_find
    stub_api(:get, "/release-notes/1").to_return(json(id: 1, slug: "version-210-20260601"))

    assert_equal "version-210-20260601", client.release_notes.find(1).slug
  end

  def test_create
    stub = stub_api(:post, "/release-notes").with(body: { title: "Version 2.1.0", content: "## New\n- Dark mode", published: true, tags: [ 1 ] })
      .to_return(json({ id: 1, published_at: "2026-06-01T09:00:00.000000Z" }, status: 201))

    note = client.release_notes.create(title: "Version 2.1.0", content: "## New\n- Dark mode", published: true, tags: [ 1 ])

    assert_equal "2026-06-01T09:00:00.000000Z", note.published_at
    assert_requested stub
  end

  def test_update_can_unpublish
    stub = stub_api(:patch, "/release-notes/1").with(body: { published: false }).to_return(json(id: 1, published_at: nil))

    assert_nil client.release_notes.update(1, published: false).published_at
    assert_requested stub
  end

  def test_the_sdk_has_no_delete_for_release_notes
    refute_respond_to client.release_notes, :delete
  end
end
