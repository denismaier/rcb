# frozen_string_literal: true

require_relative "lib/rcb/version"

Gem::Specification.new do |spec|
  spec.name          = "rcb-cascade"
  spec.version       = RCB::VERSION
  spec.authors       = ["Denis Maier"]
  spec.email         = ["denis.maier@unibe.ch"]

  spec.summary       = "Ruby Cascade Build with cascading configuration"
  spec.description   = "Rake-based build system with hierarchical configuration similar to doit-cascade"
  spec.homepage      = "https://github.com/denismaier/rcb"
  spec.license       = "CC0-1.0"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/denismaier/rcb"
  spec.metadata["changelog_uri"] = "https://github.com/denismaier/rcb/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem
  spec.files = Dir.glob("{exe,lib}/**/*") + %w[README.md LICENSE Gemfile Rakefile]
  spec.bindir        = "exe"
  spec.executables   = ["rcb"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rake", ">= 13.0"

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  # spec.add_development_dependency "rubocop", "~> 1.0"  # Requires native extensions on Windows
end
