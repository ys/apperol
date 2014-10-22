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
    -p, --personal                   Force app in personal apps instead of orgs
    -s, --stack stack                Stack for app on heroku
    -b, --branch branch              Branch to setup app from
    -r, --repo repo                  GitHub repository source
    -o, --org org                    GitHub org where the current repo is located
    -u, --user user                  GitHub user where the current repo is located
    -h, --help                       Displays Help

```

## Information

- App will be named [current_dir]-[app_extension] e.g.: direwolf-staging
- Apperol CLI will have many options based on `env` part of the `app.json`
- Apperol CLI uses heroku org by default, use `-r user/repo` to specify yours.

## Contributing

1. Fork it ( https://github.com/ys/apperol/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
