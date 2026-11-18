module FeedbackPilgrim
  class Resource
    def initialize(client)
      @client = client
    end

    def inspect
      "#<#{self.class.name}>"
    end

    private
      attr_reader :client

      def get(path, **options)    = client.request(:get, path, **options).body
      def post(path, **options)   = client.request(:post, path, **options).body
      def patch(path, **options)  = client.request(:patch, path, **options).body
      def delete(path, **options) = client.request(:delete, path, **options).body

      # The ID path parameters are integers. Integer() also keeps a slash or a
      # query out of the path.
      def member(path, id) = "#{path}/#{Integer(id)}"

      # One page of a list. Each next page keeps the filters and changes only the page.
      def paginate(path, page: nil, **query)
        Page.new(get(path, query: { **query, page: })) { |number| paginate(path, **query, page: number) }
      end

      # The API reads a date with PHP strtotime, so send a Time as ISO 8601.
      def timestamp(value)
        value.respond_to?(:iso8601) ? value.iso8601 : value
      end
  end
end
