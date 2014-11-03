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
require_relative "github_client"

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
        opts.on("--no-ext", "Name app without extension") do
          @options[:no_ext] = true
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

      if !@options[:no_ext] && !@app_extension
        $stderr.puts(parser.help)
        exit EX_USAGE
      end
    end

    def call
      launch_app_setup do |response|
        build_id = response["id"]
        output_stream_url = get_output_stream_url(build_id)
        stream_build(output_stream_url)
        finalizing_setup(build_id)
      end
    end

    private

    def launch_app_setup
      $stdout.puts("Setting up heroku app #{app_name}")
      response = heroku_client.post(app_setup_url, app_setup_payload)
      if response.status != 202
        $stderr.puts response.body["message"]
        exit 1
      else
        yield response.body
      end
    end

    def get_output_stream_url(build_id)
      response = loop_on_build_until(build_id) do |response|
        !response.body["build"]["output_stream_url"].nil? || response.body["status"] != "pending"
      end
      response.body["build"]["output_stream_url"]
    end

    def stream_build(url)
      heroku_client.stream_build(url) do |chunk|
        puts chunk
      end
    end

    def finalizing_setup(build_id)
      response = loop_on_build_until(build_id) do |response|
        response.body["status"] != "pending"
      end
      if response.body["status"] == "succeeded"
        $stdout.puts("Application #{response.body["app"]["name"]}.herokuapp.com has been successfully created.")
        exit 0
      else
        $stderr.puts("error: #{response.body["failure_message"]}")
        unless response.body["manifest_errors"].empty?
          $stderr.puts("       #{response.body["manifest_errors"]}")
        end
        unless response.body["postdeploy"].empty?
          $stderr.puts(response.body["postdeploy"]["output"])
        end
        exit 1
      end
    end

    def loop_on_build_until(build_id)
      response = nil
      spin_wait("Setting up your app", "App setup done") do
        loop do
          response = heroku_client.get(app_setup_url(build_id))
          break if yield(response)
        end
      end
      response
    end

    def app_name
      name = heroku_app_name
      unless @options[:no_ext]
        name = name + "-" + @app_extension
      end
      name
    end

    def heroku_client
      @heroku_client ||= Apperol::HerokuClient.new
    end

    def github_client
      @github_client ||= Apperol::GithubClient.new
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

    def app_setup_payload
      payload = {
        app: {
          name: app_name,
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
      $stdout.puts("Getting tarball location for #{repo}  on branch #{branch}")
      location = github_client.tarball(repo, branch)
      unless location
        $stderr.puts("error: No tarball found for #{repo}")
        exit 1
      end
      location
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
        res = github_client.get("/user")
        res.body["login"]
      }
    end

    def branch
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
