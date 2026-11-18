module FeedbackPilgrim
  # Labels for posts, release notes and contacts. A title is unique in the client.
  class Tags < Resource
    # A page of tags with posts_count and contacts_count, ordered by title.
    def list(search: nil, sort_by: nil, sort_direction: nil, per_page: nil, page: nil)
      paginate("/tags", search:, sort_by:, sort_direction:, per_page:, page:)
    end

    def create(title:) = Record.wrap(post("/tags", json: { title: }))

    def update(id, title:) = Record.wrap(patch(member("/tags", id), json: { title: }))

    # Removes the tag from each post, release note and contact, then deletes it.
    def delete(id)
      super(member("/tags", id))
      nil
    end
  end
end
