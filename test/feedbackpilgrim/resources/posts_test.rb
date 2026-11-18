require "test_helper"

class FeedbackPilgrim::PostsTest < FeedbackPilgrim::TestCase
  def test_list_with_filters
    stub = stub_api(:get, "/posts", query: {
      search: "dark mode", status: "pending", board_id: "1", tag: "feature", published: "true",
      sort_by: "title", sort_direction: "asc", per_page: "50", page: "2"
    }).to_return(paginator([ { id: 1, title: "Add dark mode", contact: { name: "Jane", metadata: '{"plan":"pro"}' } } ], current_page: 2, last_page: 2))

    page = client.posts.list(search: "dark mode", status: "pending", board_id: 1, tag: "feature", published: true,
                             sort_by: "title", sort_direction: "asc", per_page: 50, page: 2)

    assert_equal "Add dark mode", page.first.title
    assert_equal '{"plan":"pro"}', page.first.contact.metadata
    assert_requested stub
  end

  def test_list_drafts
    stub = stub_api(:get, "/posts", query: { published: "false" }).to_return(paginator([]))

    client.posts.list(published: false)

    assert_requested stub
  end

  def test_find
    stub_api(:get, "/posts/1").to_return(json(id: 1, title: "Add dark mode", comments: [ { id: 5, content: "Yes please." } ]))

    assert_equal [ "Yes please." ], client.posts.find(1).comments.map(&:content)
  end

  def test_find_takes_an_integer_id_only
    assert_raises(ArgumentError) { client.posts.find("1/../../tags") }
  end

  def test_create
    stub = stub_api(:post, "/posts")
      .with(body: { title: "Add dark mode", content: "Please add a dark theme.", status: "pending", board_id: 1, tags: [ 1, 2 ] })
      .to_return(json({ id: 1, stage: { id: 1, name: "Open", type: "open" } }, status: 201))

    post = client.posts.create(title: "Add dark mode", content: "Please add a dark theme.", status: "pending", board_id: 1, tags: [ 1, 2 ])

    assert_equal "Open", post.stage.name
    assert_requested stub
  end

  def test_create_sends_only_the_given_fields
    stub = stub_api(:post, "/posts").with(body: { title: "A", content: "B" }).to_return(json({ id: 1 }, status: 201))

    client.posts.create(title: "A", content: "B")

    assert_requested stub
  end

  def test_update_uses_patch
    stub = stub_api(:patch, "/posts/1").with(body: { status: "in_progress", tags: [] }).to_return(json({ id: 1, status: "in_progress" }))

    assert_equal "in_progress", client.posts.update(1, status: "in_progress", tags: []).status
    assert_requested stub
  end

  def test_the_sdk_has_no_delete_for_posts
    refute_respond_to client.posts, :delete
  end
end
