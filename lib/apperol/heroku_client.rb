require_relative "response"

module Apperol
  class HerokuClient

    def get(url)
      request = Net::HTTP::Get.new(url, initheader = default_headers)
      request.basic_auth *Apperol::Creds.heroku
      res = client.request(request)
      Apperol::Response.new(res.code, res.body)
    end

    def post(url, body)
      request = Net::HTTP::Post.new(url, initheader = default_headers)
      request.basic_auth *Apperol::Creds.heroku
      request.body = body
      res = client.request(request)
      Apperol::Response.new(res.code, res.body)
    end

    def stream_build(url)
      req = Net::HTTP::Get.new(url, initheader = default_headers)
      req.basic_auth *Apperol::Creds.heroku
      builds_client.request req do |response|
        response.read_body do |chunk|
          yield chunk
        end
      end
    end

    def builds_client
      @builds_client ||= Net::HTTP.new(builds_url.hostname, 443).tap do |http|
        http.use_ssl = true
      end
    end

    def builds_url
      URI("https://build-output.heroku.com")
    end

    def default_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/vnd.heroku+json; version=edge"
      }
    end

    def client
      @client ||= Net::HTTP.new("api.heroku.com", 443).tap do |http|
        http.use_ssl = true
      end
    end
  end
end
