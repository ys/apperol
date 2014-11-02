module Apperol
  class Response
    attr_accessor :status, :original_body, :headers

    def initialize(status, body, options = {})
      @status = status.to_i
      @original_body = body
      @headers = options[:headers]
    end

    def body
      @body ||= JSON.parse(original_body)
    end

    def header(key)
      @headers[key.downcase].first
    end

    def [](key)
      puts @headers
      @headers[key.downcase].first
    end
  end
end
