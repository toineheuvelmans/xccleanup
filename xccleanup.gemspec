# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xccleanup/version'

Gem::Specification.new do |spec|
  spec.name          = "xccleanup"
  spec.version       = Xccleanup::VERSION
  spec.authors       = ["Toine Heuvelmans"]
  spec.email         = ["toine@algorithmic.me"]

  spec.summary       = "A cleanup tool that assists you in cleaning up after Xcode."
  spec.homepage      = "https://github.com/toineheuvelmans/xccleanup"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
end
