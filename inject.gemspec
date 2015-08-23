# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'inject/version'

Gem::Specification.new do |spec|
  spec.name          = "dinject"
  spec.version       = Inject::VERSION
  spec.authors       = ["Danyel Bayraktar"]
  spec.email         = ["cydrop@gmail.com"]
  spec.summary       = %q{Inject objects into variables by name or symbol}
  spec.description   = %q{Inspired by angular's inject, with addition of rules and flexibility.}
  spec.homepage      = ""
  spec.licenses      = ["MIT"]

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.0.0"
  spec.add_dependency "pqueue", "~> 2.1"
end
