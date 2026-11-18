$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "feedbackpilgrim"
require "minitest/autorun"
require "webmock/minitest"

module FeedbackPilgrim
  class TestCase < Minitest::Test
    URL = "https://feedback.example.com"
    TOKEN = "1|test-token"

    def setup
      WebMock.disable_net_connect!
    end

    def fixture(name)
      JSON.parse(File.read(File.expand_path("fixtures/#{name}", __dir__)))
    end

    # A client that records each pause instead of sleeping.
    def client(**options)
      Client.new(url: URL, token: TOKEN, **options).tap do |client|
        client.instance_variable_set(:@pauses, [])
        def client.pauses = @pauses
        def client.pause(seconds) = @pauses << seconds
      end
    end

    def stub_api(method, path, query: nil)
      stub = stub_request(method, "#{URL}/api/public/v1#{path}")
      query ? stub.with(query:) : stub
    end

    def json(body = nil, status: 200, headers: {}, **fields)
      { status:, body: JSON.generate(body.nil? ? fields : body), headers: { "Content-Type" => "application/json", **headers } }
    end

    # A flat Laravel paginator, like the list responses of the API.
    def paginator(data, current_page: 1, last_page: 1, per_page: 15, path: "/posts")
      next_page_url = "#{URL}/api/public/v1#{path}?page=#{current_page + 1}" if current_page < last_page
      json(current_page:, data:, first_page_url: "#{URL}/api/public/v1#{path}?page=1", from: data.empty? ? nil : 1,
           last_page:, last_page_url: "#{URL}/api/public/v1#{path}?page=#{last_page}", links: [], next_page_url:,
           path: "#{URL}/api/public/v1#{path}", per_page:, prev_page_url: nil, to: data.size, total: data.size)
    end
  end
end
