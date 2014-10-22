require "bundler"
require "net/http"
require "openssl"
require "json"
require "optparse"
require "netrc"
require "spinning_cursor"

module Apperol
  class CLI
    EX_USAGE = 64

    def initialize(args = [])
      @options = {}

      parser = OptionParser.new do|opts|
        opts.banner = "Usage: apperol [options] [app_extension]"
        app_json["env"].each do |key, definition|
          option_key_name = key.downcase.gsub("_", "-")
          option_key_key = key.downcase.to_sym
          # Set default
          @options[option_key_key] = definition["value"]
          opts.on("--#{option_key_name} value", "#{definition["description"]} (Default: '#{definition["value"]}')") do |value|
            @options[option_key_key] = value
          end
        end
        opts.on("-p", "--personal", "Force app in personal apps instead of orgs") do
          @options[:personal] = true
        end
        opts.on("-r", "--repo repo", "GitHub repository used for the deploy") do |repo|
          @options[:repo] = repo
        end
        opts.on("-s", "--stack stack", "Stack for app on heroku") do |stack|
          @options[:stack] = stack
        end
        opts.on("-b", "--branch branch", "Branch to setup app from") do |branch|
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
      heroku_app_setup
    end

    def heroku_app_setup
      req = Net::HTTP::Post.new(app_setup_url, initheader = heroku_headers)
      req.basic_auth *heroku_creds
      req.body = app_setup_payload
      $stdout.puts("Setting up heroku app #{heroku_app_name}-#{@app_extension}")
      res = heroku_http.request(req)
      if res.code != "202"
        $stderr.puts JSON.parse(res.body)["message"]
        exit 1
      else
        poll_app_status(JSON.parse(res.body))
      end
    end

    def poll_app_status(response)
      req = Net::HTTP::Get.new(app_setup_url(response["id"]), initheader = heroku_headers)
      req.basic_auth *heroku_creds
      res = {}
      spin_wait("Setting up your app", "App setup done") do
        loop do
          res = JSON.parse(heroku_http.request(req).body)
          break unless res["status"] == "pending"
        end
      end
      if res["status"] == "succeeded"
        unless res["postdeploy"].empty?
          $stdout.puts(res["postdeploy"]["output"])
        end
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

    def spin_wait(banner_txt, message_txt)
      SpinningCursor.run do
        banner banner_txt
        type :dots
        message message_txt
      end

      yield

      SpinningCursor.stop
    end

    def app_setup_url(id = nil)
      URI("https://api.heroku.com/app-setups/#{id}")
    end

    def heroku_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/vnd.heroku+json; version=3"
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
      app_json["env"].each do |key, definition|
        value = @options[key.downcase.to_sym]
        if definition["required"] && value.strip.empty?
          required_not_filled << key
        end
        payload[:overrides][:env][key] = value
      end
      unless required_not_filled.empty?
        $stderr.puts("error: Required fields not filled. Please specify them. #{required_not_filled}")
        exit 1
      end
      payload[:app][:organization] = "heroku" unless personal_app?
      payload.to_json
    end

    def github_tarball_location
      $stdout.puts("Getting tarball location for empirical branch #{github_branch}")
      req = Net::HTTP::Get.new(github_url)
      req.basic_auth *github_creds
      res = github_http.request(req)
      if res["Location"]
        res["Location"]
      else
        $stderr.puts("error: No tarball found for #{github_url} : #{JSON.parse(res.body)["message"]}")
        exit 1
      end
    end

    def github_http
      @github_http ||= Net::HTTP.new(github_url.hostname, github_url.port).tap do |http|
        http.use_ssl = true
      end
    end

    def personal_app?
      @options.fetch(:personal, false)
    end

    def repo
      @options.fetch(:repo, "heroku/#{heroku_app_name}")
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
      @github_url ||= URI("https://api.github.com/repos/#{repo}/tarball/#{github_branch}")
    end

    def github_creds
      netrc["api.github.com"]
    end

    def heroku_creds
      netrc["api.heroku.com"]
    end

    def netrc
      @netrc ||= Netrc.read
    end

    def heroku_app_name
      Dir.pwd.split("/").last
    end

    def app_json
      unless File.exists?("app.json")
        $stderr.puts("No app.json file here")
        exit 1
      end
      @app_json ||= JSON.parse(File.read("app.json"))
    end
  end
end
