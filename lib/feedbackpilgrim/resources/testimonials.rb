module FeedbackPilgrim
  # Customer testimonials. The API cannot delete a testimonial.
  class Testimonials < Resource
    # A page of testimonials with their contact, votes and comments. Without
    # approved: true, the page has only the pending testimonials.
    def list(approved: nil, search: nil, rating: nil, sort_by: nil, sort_direction: nil, per_page: nil, page: nil)
      paginate("/testimonials", approved:, search:, rating:, sort_by:, sort_direction:, per_page:, page:)
    end

    def find(id) = Record.wrap(get(member("/testimonials", id)))

    # A new testimonial is pending. contact_id links it to a contact.
    def create(description:, username:, rating: nil, contact_id: nil)
      Record.wrap(post("/testimonials", json: { description:, username:, rating:, contact_id: }.compact))
    end

    # Changes only the given fields. Set approved_at to approve the testimonial.
    def update(id, description: nil, rating: nil, username: nil, approved_at: nil)
      body = { description:, rating:, username:, approved_at: timestamp(approved_at) }.compact
      Record.wrap(patch(member("/testimonials", id), json: body))
    end

    def approve(id, at: Time.now) = update(id, approved_at: at)
  end
end
