require "bundler"
require "net/http"
require "openssl"
require "json"
require "optparse"
require "netrc"
require "spinning_cursor"

require_relative "app_json"
require_relative "creds"
require_relative "heroku_client"

module Apperol
  class CLI
    EX_USAGE = 64

    def initialize(args = [])
      @options = {}

      parser = OptionParser.new do|opts|
        opts.banner = "Usage: apperol [options] [app_extension]"
        app_json.env.each do |env_value|
          option_key_name = env_value.key.downcase.gsub("_", "-")
          opts.on("--#{option_key_name} value", "#{env_value.description} (Default: '#{env_value.value}' #{env_value.required?}) ") do |value|
            @options[env_value.key] = value
          end
        end
        opts.on("-o", "--org ORG", "Push app to organization on heroku") do |org|
          @options[:org] = org
        end
        opts.on("-r", "--repo REPO", "GitHub repository used for the deploy (Default: user/dir_name)") do |repo|
          @options[:repo] = repo
        end
        opts.on("-u", "--user USER", "GitHub user where current repo is located (Default: Your GitHub username)") do |user|
          @options[:user] = user
        end
        opts.on("-s", "--stack STACK", "Stack for app on heroku (Default: cedar-14)") do |stack|
          @options[:stack] = stack
        end
        opts.on("-b", "--branch BRANCH", "Branch to setup app from (Default: master)") do |branch|
          @options[:branch] = branch
        end
        opts.on('-h', '--help', 'Displays Help') do
          puts opts
          exit EX_USAGE
        end
      end
      parser.parse!(args)

      @app_extension = args.shift

      unless @app_extension
        $stderr.puts("usage: apperol [options] [app_extension]")
        exit EX_USAGE
      end
    end

    def call
      launch_app_setup do |response|
        poll_app_status(response)
      end
    end

    def launch_app_setup
      $stdout.puts("Setting up heroku app #{heroku_app_name}-#{@app_extension}")
      response = heroku_client.post(app_setup_url, app_setup_payload)
      json_body = JSON.parse(response.body)
      if response.code != "202"
        $stderr.puts json_body["message"]
        exit 1
      else
        yield json_body
      end
    end

    def poll_app_status(response)
      build_id = response["id"]
      output_stream_url = get_output_stream_url(build_id)
      stream_build(output_stream_url)
      finalizing_setup(build_id)
    end

    def finalizing_setup(build_id)
      res = {}
      spin_wait("Finalizing setup", "App setup done") do
        loop do
          res = JSON.parse(heroku_client.get(app_setup_url(build_id)).body)
          break unless res["status"] == "pending"
        end
      end
      if res["status"] == "succeeded"
        $stdout.puts("Application #{res["app"]["name"]}.herokuapp.com has been successfully created.")
        exit 0
      else
        $stderr.puts("error: #{res["failure_message"]}")
        unless res["manifest_errors"].empty?
          $stderr.puts("       #{res["manifest_errors"]}")
        end
        unless res["postdeploy"].empty?
          $stderr.puts(res["postdeploy"]["output"])
        end
        exit 1
      end
    end

    def get_output_stream_url(build_id)
      res = {}
      spin_wait("Setting up your app", "App setup done") do
        loop do
          res = JSON.parse(heroku_client.get(app_setup_url(build_id)).body)
          break unless res["build"]["output_stream_url"].nil? || res["status"] != "pending"
        end
      end
      res["build"]["output_stream_url"]
    end

    def stream_build(url)
      req = Net::HTTP::Get.new(url, initheader = heroku_headers)
      req.basic_auth *Apperol::Creds.heroku
      builds = URI("https://build-output.heroku.com")
      builds_http ||= Net::HTTP.new(builds.hostname, builds.port).tap do |http|
        http.use_ssl = true
      end
      builds_http.request req do |response|
        response.read_body do |chunk|
          puts chunk
        end
      end
    end

    def heroku_client
      @heroku_client ||= Apperol::HerokuClient.new
    end

    def spin_wait(banner_txt, message_txt)
      SpinningCursor.run do
        banner banner_txt
        type :dots
        message message_txt
      end

      yield

      SpinningCursor.stop
    end

    def heroku_auth_request(url)
      req = Net::HTTP::Get.new(url , initheader = heroku_headers)
      req.basic_auth *Apperol::Creds.heroku
      req
    end

    def app_setup_url(id = nil)
      URI("https://api.heroku.com/app-setups/#{id}")
    end

    def heroku_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/vnd.heroku+json; version=edge"
      }
    end

    def heroku_http
      @heroku_http ||= Net::HTTP.new(app_setup_url.hostname, app_setup_url.port).tap do |http|
        http.use_ssl = true
      end
    end

    def app_setup_payload
      payload = {
        app: {
          name: "#{heroku_app_name}-#{@app_extension}",
          stack: stack
        },
        source_blob: { url: github_tarball_location },
        overrides: { env: {}}
      }
      required_not_filled = []
      app_json.env.each do |env_value|
        value = @options[env_value.key]
        value_empty = value.nil? || value.strip.empty?
        if env_value.needs_value? && value_empty
          required_not_filled << env_value.key
        end
        payload[:overrides][:env][env_value.key] = value unless value_empty
      end
      unless required_not_filled.empty?
        $stderr.puts("error: Required fields not filled. Please specify them. #{required_not_filled}")
        exit 1
      end
      payload[:app][:organization] = org unless personal_app?
      payload.to_json
    end

    def github_tarball_location
      $stdout.puts("Getting tarball location for empirical branch #{github_branch}")
      res = github_get(tarball_path)
      if res["Location"]
        res["Location"]
      else
        $stderr.puts("error: No tarball found for #{github_url + tarball_path} : #{JSON.parse(res.body)["message"]}")
        exit 1
      end
    end

    def github_get(path)
      puts github_url + path
      req = Net::HTTP::Get.new(github_url + path)
      req.basic_auth *Apperol::Creds.github
      github_http.request(req)
    end

    def github_http
      @github_http ||= Net::HTTP.new(github_url.hostname, github_url.port).tap do |http|
        http.use_ssl = true
      end
    end

    def personal_app?
      org.nil?
    end

    def org
      @options.fetch(:org, nil)
    end

    def repo
      @options.fetch(:repo, default_repo)
    end

    def default_repo
      "#{user}/#{heroku_app_name}"
    end

    def user
      @user ||= @options.fetch(:user) {
        res = github_get("/user")
        JSON.parse(res.body)["login"]
      }
    end

    def rollbar_token
      @options.fetch(:rollbar_token) {
        $stdout.puts("Missing rollbar_token option, its not required but you won't have exception tracking")
        ""
      }
    end

    def github_branch
      @options.fetch(:branch, "master")
    end

    def stack
      @options.fetch(:stack, "cedar-14")
    end

    def rack_env
      @options.fetch(:rack_env) {
        @app_extension == "production" ? "production" : "staging"
      }
    end

    def github_url
      URI("https://api.github.com")
    end

    def tarball_path
      "/repos/#{repo}/tarball/#{github_branch}"
    end

    def heroku_app_name
      Dir.pwd.split("/").last
    end

    def app_json
      unless File.exists?("app.json")
        $stderr.puts("No app.json file here")
        exit 1
      end
      @app_json ||= AppJson.new("app.json")
    end
  end
end
