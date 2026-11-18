require "test_helper"

class FeedbackPilgrim::ContactsTest < FeedbackPilgrim::TestCase
  def test_list_returns_custom_fields_as_fields
    stub = stub_api(:get, "/contacts", query: { search: "jane", tag: "vip", sort_by: "mrr", sort_direction: "desc" })
      .to_return(paginator([ { id: 7, email: "jane@example.com", plan: "pro", tags: [], votes: [] } ], path: "/contacts"))

    contact = client.contacts.list(search: "jane", tag: "vip", sort_by: "mrr", sort_direction: "desc").first

    assert_equal "pro", contact.plan
    assert_requested stub
  end

  def test_find
    stub_api(:get, "/contacts/7").to_return(json(id: 7, name: "Jane Smith"))

    assert_equal "Jane Smith", client.contacts.find(7).name
  end

  def test_upsert_creates_a_contact
    stub = stub_api(:post, "/contacts")
      .with(body: { email: "jane@example.com", name: "Jane Smith", mrr: 149.99, ltv: 1800, avatar: "https://example.com/jane.jpg", tags: [ 1 ], metadata: { plan: "pro" } })
      .to_return(json({ id: 7, email: "jane@example.com", plan: "pro" }, status: 201))

    contact = client.contacts.upsert(email: "jane@example.com", name: "Jane Smith", mrr: 149.99, ltv: 1800,
                                     avatar: "https://example.com/jane.jpg", tags: [ 1 ], custom_fields: { plan: "pro" })

    assert_predicate contact, :created?
    assert_equal "pro", contact.plan
    assert_requested stub
  end

  def test_upsert_updates_a_contact_with_the_same_email
    stub_api(:post, "/contacts").with(body: { email: "jane@example.com", name: "Jane" }).to_return(json({ id: 7 }, status: 200))

    contact = client.contacts.upsert(email: "jane@example.com", name: "Jane")

    refute_predicate contact, :created?
    assert_equal 7, contact.id
  end

  def test_update_uses_patch_and_sends_no_custom_fields
    stub = stub_api(:patch, "/contacts/7").with(body: { name: "Jane S.", mrr: 199 }).to_return(json(id: 7, name: "Jane S.", mrr: 199))

    assert_equal 199, client.contacts.update(7, name: "Jane S.", mrr: 199).mrr
    assert_requested stub
  end

  def test_update_does_not_accept_custom_fields
    assert_raises(ArgumentError) { client.contacts.update(7, plan: "pro") }
  end

  def test_the_sdk_has_no_delete_for_contacts
    refute_respond_to client.contacts, :delete
  end
end
