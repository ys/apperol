# Apperol

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
    -p, --personal                   Force app in personal apps instead of orgs
    -s, --stack stack                Stack for app on heroku
    -b, --branch branch              Branch to setup app from
    -h, --help                       Displays Help
```

## Information

- App will be named [current_dir]-[app_extension] e.g.: direwolf-staging
- Apperol CLI will have many options based on `env` part of the `app.json`

## Contributing

1. Fork it ( https://github.com/[my-github-username]/apperol/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
