module Apperol
  class HerokuClient

    def get(url)
      request = Net::HTTP::Get.new(url, initheader = heroku_headers)
      request.basic_auth *Apperol::Creds.heroku
      http.request(request)
    end

    def post(url, body)
      request = Net::HTTP::Post.new(url, initheader = heroku_headers)
      request.basic_auth *Apperol::Creds.heroku
      request.body = body
      http.request(request)
    end

    def heroku_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/vnd.heroku+json; version=edge"
      }
    end

    def http
      @http ||= Net::HTTP.new("api.heroku.com", 443).tap do |http|
        http.use_ssl = true
      end
    end
  end
end
