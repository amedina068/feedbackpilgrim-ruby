require "test_helper"

class FeedbackPilgrim::RecordTest < FeedbackPilgrim::TestCase
  def test_reads_fields_as_methods_and_with_brackets
    record = FeedbackPilgrim::Record.new("title" => "Add dark mode", "contact" => { "name" => "Jane" }, "tags" => [ { "title" => "feature" } ])

    assert_equal "Add dark mode", record.title
    assert_equal "Add dark mode", record[:title]
    assert_equal "Jane", record.contact.name
    assert_equal [ "feature" ], record.tags.map(&:title)
  end

  def test_an_unknown_field_raises
    record = FeedbackPilgrim::Record.new(title: "x")

    assert_raises(NoMethodError) { record.missing }
    assert_nil record[:missing]
    refute_respond_to record, :missing
    assert_respond_to record, :title
  end

  def test_equality_and_to_h
    assert_equal FeedbackPilgrim::Record.new(id: 1), FeedbackPilgrim::Record.new("id" => 1)
    assert_equal({ "id" => 1 }, FeedbackPilgrim::Record.new(id: 1).to_h)
  end
end
