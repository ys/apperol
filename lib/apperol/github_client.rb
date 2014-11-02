require_relative "response"

module Apperol
  class GithubClient

    def tarball(repository, branch = "master")
      tarball_path = "/repos/#{repository}/tarball/#{branch}"
      res = get(tarball_path)
      res.header("Location")
    end

    def get(path)
      req = Net::HTTP::Get.new(url + path)
      req.basic_auth *Apperol::Creds.github
      res = client.request(req)
      Apperol::Response.new(res.code, res.body, headers: res.to_hash)
    end

    def client
      @client ||= Net::HTTP.new(url.hostname, url.port).tap do |http|
        http.use_ssl = true
      end
    end

    def url
      URI("https://api.github.com")
    end
  end
end
