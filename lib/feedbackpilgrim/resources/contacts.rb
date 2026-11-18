module FeedbackPilgrim
  # The customers of the client. Each custom field of a contact is a field of
  # the record, for example contact.plan.
  class Contacts < Resource
    # The contact that upsert returns. created? is true when the email was new (HTTP 201).
    class Saved < Record
      def initialize(attributes, created:)
        super(attributes)
        @created = created
      end

      def created? = @created
    end

    # A page of contacts with their tags and votes.
    def list(search: nil, tag: nil, sort_by: nil, sort_direction: nil, per_page: nil, page: nil)
      paginate("/contacts", search:, tag:, sort_by:, sort_direction:, per_page:, page:)
    end

    def find(id) = Record.wrap(get(member("/contacts", id)))

    # Creates the contact, or updates the contact that has this email. The app
    # merges custom_fields with the custom fields that the contact has.
    #
    # A repeated request leaves the same contact, so the client can retry it.
    def upsert(email:, name:, mrr: nil, ltv: nil, avatar: nil, tags: nil, custom_fields: nil)
      body = { email:, name:, mrr:, ltv:, avatar:, tags:, metadata: custom_fields }.compact
      response = client.request(:post, "/contacts", json: body, idempotent: true)

      Saved.new(response.body, created: response.status == 201)
    end

    # Changes only the given fields. tags replaces all the tags of the contact.
    # To change custom fields, use upsert with the email of the contact.
    def update(id, name: nil, email: nil, mrr: nil, ltv: nil, avatar: nil, tags: nil)
      Record.wrap(patch(member("/contacts", id), json: { name:, email:, mrr:, ltv:, avatar:, tags: }.compact))
    end
  end
end
