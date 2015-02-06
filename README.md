# Apperol

![](http://cl.ly/image/0C230a0p2p0G/apperol.png)

Create apps from heroku repositories on GitHub.
Use app.json to customize options.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'apperol'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install apperol

## Usage

```
Usage: apperol [options] [app_extension]
    -o, --org ORG                    Push app to organization on heroku
    -r, --repo REPO                  GitHub repository used for the deploy (Default: user/dir_name)
    -u, --user USER                  GitHub user where current repo is located (Default: Your GitHub username)
    -s, --stack STACK                Stack for app on heroku (Default: cedar-14)
        --no-ext                     Name app without extension
    -b, --branch BRANCH              Branch to setup app from (Default: master)
    -h, --help                       Displays Help
```

## Information

- App will be named [current_dir]-[app_extension] e.g.: direwolf-staging
- Apperol CLI will have many options based on `env` part of the `app.json`
- Apperol CLI uses heroku org by default, use `-r user/repo` to specify yours.

## Credentials
Apperol will look in ~/.netrc for api.github.com and api.heroku.com credentials.

## Development

```bash
git clone git@github.com:ys/apperol.git
bundle install
bundle exec ruby -llib bin/apperol
```

## Lack of tests

I know it is bad but they will come before v1.0.0 .
If you dislike this, see next section.

## Contributing

1. Fork it ( https://github.com/ys/apperol/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
