# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails5/spec_converter/version'

Gem::Specification.new do |spec|
  spec.name          = "rails5-spec-converter"
  spec.version       = Rails5::SpecConverter::VERSION
  spec.authors       = ["Travis Grathwell"]
  spec.email         = ["tjgrathwell@gmail.com"]

  spec.summary       = %q{A tool to upgrade Rails 4-style specs to Rails 5-style}
  spec.description   = %q{Rails 5 issues a deprecation warning if your controller/request tests don't wrap user-supplied params in a `params` keyword. This helps with that.}
  spec.homepage      = "https://github.com/tjgrathwell/rails5-spec-converter"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*") + %w(CHANGELOG.md LICENSE.txt README.md Rakefile)
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'parser',        '>= 2.3.0.7'
  spec.add_runtime_dependency 'astrolabe',     '~> 1.2'

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "byebug"
end
