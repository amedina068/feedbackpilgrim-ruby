module FeedbackPilgrim
  # Feature requests and other feedback. The API cannot delete a post.
  class Posts < Resource
    # A page of posts with their contact, tags and votes. status is pending,
    # in_progress or completed. tag is the exact title of a tag.
    def list(search: nil, status: nil, board_id: nil, tag: nil, published: nil,
             sort_by: nil, sort_direction: nil, per_page: nil, page: nil)
      paginate("/posts", search:, status:, board_id:, tag:, published:, sort_by:, sort_direction:, per_page:, page:)
    end

    # One post with its contact, tags, votes and comments.
    def find(id) = Record.wrap(get(member("/posts", id)))

    # Without board_id, the post goes on the first board of the client.
    def create(title:, content:, status: nil, board_id: nil, tags: nil)
      Record.wrap(post("/posts", json: { title:, content:, status:, board_id:, tags: }.compact))
    end

    # Changes only the given fields. tags replaces all the tags of the post. A new
    # status moves the post to a stage and sends the same emails and webhooks as the dashboard.
    def update(id, title: nil, content: nil, status: nil, board_id: nil, tags: nil)
      Record.wrap(patch(member("/posts", id), json: { title:, content:, status:, board_id:, tags: }.compact))
    end
  end
end
