require "gemstash"
require "faraday"
require "faraday_middleware"
require "set"

module Gemstash
  #:nodoc:
  class WebError < StandardError
    attr_reader :code

    def initialize(message, code)
      @code = code
      super(message)
    end
  end

  #:nodoc:
  class GemFetcher
    def initialize(http_client)
      @http_client = http_client
      @valid_headers = Set.new(["etag", "content-type", "content-length", "last-modified"])
    end

    def fetch(gem_id, &block)
      @http_client.get("/gems/#{gem_id}") do |body, headers|
        properties = filter_headers(headers)
        validate_download(body, properties)
        yield body, properties
      end
    end

  private

    def filter_headers(headers)
      headers.inject({}) do|properties, (key, value)|
        properties[key.downcase] = value if @valid_headers.include?(key.downcase)
        properties
      end
    end

    def validate_download(content, headers)
      expected_size = content_length(headers)
      raise "Incomplete download, only #{body.length} was downloaded out of #{expected_size}" \
        if content.length < expected_size
    end

    def content_length(headers)
      headers["content-length"].to_i
    end
  end

  #:nodoc:
  class HTTPClient
    def self.for(server_url)
      client = Faraday.new(server_url) do |config|
        config.use FaradayMiddleware::FollowRedirects
        config.adapter :net_http
      end

      new(client)
    end

    def initialize(client = nil)
      @client = client
    end

    def get(path)
      response = @client.get(path) do |req|
        req.options.open_timeout = 2
      end

      raise WebError.new(response.body, response.status) unless response.success?

      if block_given?
        yield(response.body, response.headers)
      else
        response.body
      end
    end
  end
end
