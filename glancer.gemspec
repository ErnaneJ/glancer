# frozen_string_literal: true

require_relative "lib/glancer/version"

Gem::Specification.new do |spec|
  spec.name = "glancer"
  spec.version = Glancer::VERSION
  spec.authors = ["Ernane Ferreira"]
  spec.email = ["ernane.junior25@gmail.com"]

  spec.summary = "RAG-driven AI interface for querying Rails databases"
  spec.description = "Glancer is a Ruby on Rails engine that enables natural language queries over your database using RAG (Retrieval-Augmented Generation) and LLMs."
  spec.homepage = "https://github.com/ernanej/glancer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # Metadata
  spec.metadata["allowed_push_host"]   = "https://rubygems.org"
  spec.metadata["homepage_uri"]        = spec.homepage
  spec.metadata["source_code_uri"]     = "https://github.com/ernanej/glancer"
  spec.metadata["changelog_uri"]       = "https://github.com/ernanej/glancer/blob/main/CHANGELOG.md"

  # Included files
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").select { |f| f =~ /\.(rb|md|yml|erb|rake)$/ || f.start_with?("lib/") }
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "ruby_llm", "~> 1.3.1"
end
