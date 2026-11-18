module FeedbackPilgrim
  # One page of a list. The API returns a flat Laravel paginator, so meta holds
  # the page fields, for example current_page, last_page, per_page and total.
  #
  #   page = FeedbackPilgrim.posts.list(per_page: 100)
  #   page.each { |post| puts post.title }
  #   page.next_page if page.next_page?
  #
  # each_record walks every page:
  #
  #   FeedbackPilgrim.posts.list(per_page: 100).each_record { |post| puts post.title }
  class Page
    include Enumerable

    attr_reader :records, :meta

    def initialize(body, &next_page)
      @records = Record.wrap(body["data"] || [])
      @meta = Record.wrap(body.except("data"))
      @next_page = next_page
    end

    def each(&) = records.each(&)

    def next_page?
      !meta[:next_page_url].nil?
    end

    def next_page
      @next_page.call(meta[:current_page] + 1) if next_page?
    end

    # Enumerates the records of this page and of each page after it.
    # Without a block, returns an Enumerator that reads a page only when it needs it.
    def each_record(&block)
      return enum_for(:each_record) unless block

      page = self
      while page
        page.each(&block)
        page = page.next_page
      end
    end
  end
end
