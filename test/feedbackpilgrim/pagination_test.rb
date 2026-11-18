require "test_helper"

class FeedbackPilgrim::PaginationTest < FeedbackPilgrim::TestCase
  def test_a_page_has_records_and_meta
    stub_api(:get, "/posts").to_return(paginator([ { id: 2, title: "B" }, { id: 1, title: "A" } ], last_page: 3))

    page = client.posts.list

    assert_equal [ "B", "A" ], page.map(&:title)
    assert_equal 1, page.meta.current_page
    assert_equal 3, page.meta.last_page
    assert_equal 15, page.meta.per_page
    refute page.meta.key?(:data)
    assert_predicate page, :next_page?
  end

  def test_next_page_asks_for_the_next_page_number_and_keeps_the_filters
    stub_api(:get, "/posts", query: { status: "pending", per_page: "2" }).to_return(paginator([ { id: 3 }, { id: 2 } ], last_page: 2, per_page: 2))
    second = stub_api(:get, "/posts", query: { status: "pending", per_page: "2", page: "2" })
      .to_return(paginator([ { id: 1 } ], current_page: 2, last_page: 2, per_page: 2))

    page = client.posts.list(status: "pending", per_page: 2).next_page

    assert_equal [ 1 ], page.map(&:id)
    refute_predicate page, :next_page?
    assert_nil page.next_page
    assert_requested second
  end

  def test_each_record_walks_every_page
    stub_api(:get, "/contacts", query: { per_page: "100" }).to_return(paginator([ { id: 3 }, { id: 2 } ], last_page: 3, path: "/contacts"))
    stub_api(:get, "/contacts", query: { per_page: "100", page: "2" }).to_return(paginator([ { id: 1 } ], current_page: 2, last_page: 3, path: "/contacts"))
    stub_api(:get, "/contacts", query: { per_page: "100", page: "3" }).to_return(paginator([], current_page: 3, last_page: 3, path: "/contacts"))

    ids = []
    client.contacts.list(per_page: 100).each_record { |contact| ids << contact.id }

    assert_equal [ 3, 2, 1 ], ids
  end

  def test_each_record_without_a_block_is_a_lazy_enumerator
    stub_api(:get, "/tags").to_return(paginator([ { id: 2 } ], last_page: 2, path: "/tags"))
    second = stub_api(:get, "/tags", query: { page: "2" }).to_return(paginator([ { id: 1 } ], current_page: 2, last_page: 2, path: "/tags"))

    records = client.tags.list.each_record

    assert_equal 2, records.first.id
    assert_not_requested second
    assert_equal [ 2, 1 ], records.map(&:id)
  end

  def test_a_list_can_start_at_a_page
    stub = stub_api(:get, "/release-notes", query: { page: "4" }).to_return(paginator([], current_page: 4, last_page: 4))

    client.release_notes.list(page: 4)

    assert_requested stub
  end

  def test_an_empty_list
    stub_api(:get, "/testimonials").to_return(paginator([]))

    page = client.testimonials.list

    assert_empty page.records
    refute_predicate page, :next_page?
    assert_equal [], page.each_record.to_a
  end
end
