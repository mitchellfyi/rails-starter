# frozen_string_literal: true

require_relative "lib/railsplan/version"

Gem::Specification.new do |spec|
  spec.name = "railsplan"
  spec.version = RailsPlan::VERSION
  spec.authors = ["RailsPlan Team"]
  spec.email = ["team@railsplan.dev"]

  spec.summary = "Global CLI for Rails SaaS Bootstrapping"
  spec.description = "A comprehensive CLI tool for generating full-stack, AI-native, production-ready Rails SaaS applications with modular architecture."
  spec.homepage = "https://github.com/railsplan/railsplan"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mitchellfyi/railsplan"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{bin,lib,templates,scaffold}/**/*") + %w[LICENSE.txt CHANGELOG.md]
  spec.bindir = "bin"
  spec.executables = ["railsplan"]
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "tty-spinner", "~> 0.9"
  spec.add_dependency "tty-command", "~> 0.10"
  spec.add_dependency "tty-which", "~> 0.5"
  spec.add_dependency "tty-file", "~> 0.8"
  spec.add_dependency "tty-logger", "~> 0.6"
  spec.add_dependency "tty-config", "~> 0.6"
  spec.add_dependency "tty-table", "~> 0.12"
  spec.add_dependency "tty-markdown", "~> 0.7"
  spec.add_dependency "tty-progressbar", "~> 0.18"
  spec.add_dependency "tty-screen", "~> 0.8"
  spec.add_dependency "tty-cursor", "~> 0.5"
  spec.add_dependency "tty-reader", "~> 0.9"
  spec.add_dependency "tty-editor", "~> 0.6"
  spec.add_dependency "tty-pager", "~> 0.14"
  spec.add_dependency "tty-link", "~> 0.1"
  spec.add_dependency "tty-font", "~> 0.5"
  spec.add_dependency "tty-box", "~> 0.7"
  spec.add_dependency "tty-tree", "~> 0.4"
  spec.add_dependency "tty-color", "~> 0.5"
  spec.add_dependency "tty-platform", "~> 0.3"
  spec.add_dependency "tty-option", "~> 0.2"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 2.20"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
end 