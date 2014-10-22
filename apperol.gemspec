# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apperol/version'

Gem::Specification.new do |spec|
  spec.name          = "apperol"
  spec.version       = Apperol::VERSION
  spec.authors       = ["Yannick"]
  spec.email         = ["yannick@heroku.com"]
  spec.summary       = %q{Create heroku app from heroku repository}
  spec.description   = %q{Create heroku app from heroku repository with app.json}
  spec.homepage      = "https://github.com/ys/apperol"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "netrc", "~> 0.8.0"
  spec.add_dependency "spinning_cursor", "~> 0.3.0"
end
