module FeedbackPilgrim
  # Changelog entries. The API cannot delete a release note.
  class ReleaseNotes < Resource
    # A page of release notes with their tags, votes and comments.
    def list(search: nil, published: nil, tag: nil, sort_by: nil, sort_direction: nil, per_page: nil, page: nil)
      paginate("/release-notes", search:, published:, tag:, sort_by:, sort_direction:, per_page:, page:)
    end

    def find(id) = Record.wrap(get(member("/release-notes", id)))

    # Without published: true, the note is a draft. The owner of the token is the author.
    def create(title:, content:, published: nil, tags: nil)
      Record.wrap(post("/release-notes", json: { title:, content:, published:, tags: }.compact))
    end

    # published: true keeps a publication date that exists. published: false makes
    # the note a draft. tags replaces all the tags of the note.
    def update(id, title: nil, content: nil, published: nil, tags: nil)
      Record.wrap(patch(member("/release-notes", id), json: { title:, content:, published:, tags: }.compact))
    end
  end
end
