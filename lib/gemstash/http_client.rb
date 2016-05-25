require "gemstash"
require "faraday"
require "faraday_middleware"

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
  class ConnectionError < WebError
    def initialize(message)
      super(message, 502) # Bad Gateway
    end
  end

  #:nodoc:
  class HTTPClient
    include Gemstash::Logging

    DEFAULT_USER_AGENT = "Gemstash/#{Gemstash::VERSION}"

    def self.for(upstream)
      client = Faraday.new(upstream.to_s) do |config|
        config.use FaradayMiddleware::FollowRedirects
        config.adapter :net_http
      end
      user_agent = "#{upstream.user_agent} " unless upstream.user_agent.to_s.empty?
      user_agent = user_agent.to_s + DEFAULT_USER_AGENT

      new(client, user_agent: user_agent)
    end

    def initialize(client = nil, user_agent: nil)
      @client = client
      @user_agent = user_agent || DEFAULT_USER_AGENT
    end

    def get(path)
      response = request(:get, path)
      if block_given?
        yield(response.body, response.headers)
      else
        response.body
      end
    end

    def head(path)
      response = request(:head, path)
      if block_given?
        yield response.headers
      else
        response.headers
      end
    end

  private

    def request(method, path)
      response = with_retries do
        @client.public_send(method, path) do |request|
          request.headers["User-Agent"] = @user_agent
          request.options.open_timeout = 2
        end
      end
      raise Gemstash::WebError.new(response.body, response.status) unless response.success?
      response
    end

    def with_retries(times: 3, &block)
      loop do
        times -= 1
        begin
          return block.call
        rescue Faraday::ConnectionFailed => e
          log_error("Connection failure", e)
          raise(ConnectionError, e.message) unless times > 0
          log.info "retrying... #{times} more times"
        end
      end
    end
  end
end
