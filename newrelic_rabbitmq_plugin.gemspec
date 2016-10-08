# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'newrelic_rabbitmq_plugin/version'

Gem::Specification.new do |spec|
  spec.name          = "newrelic_rabbitmq_plugin"
  spec.version       = NewrelicRabbitmqPlugin::VERSION
  spec.authors       = ["Joel Jensen"]
  spec.email         = ["joel.jensen@iorahealth.com"]

  spec.summary       = %q{"New Relic plugin for reporting RabbitMQ statistics"}
  spec.description   = %q{"New Relic plugin for reporting RabbitMQ statistics"}
  spec.homepage      = "https://github.com/iorahealth/newrelic_rabbitmq_plugin"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.rdoc_options = ["--charset=UTF-8"]
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_runtime_dependency('faraday',    "~> 0.9.0")
  spec.add_runtime_dependency('faraday_middleware',  "~> 0.9.1")
  spec.add_runtime_dependency('newrelic_plugin')
end
