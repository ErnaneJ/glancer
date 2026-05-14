# frozen_string_literal: true

if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"
  require "simplecov-json"

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ]

  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/lib/generators/"

    add_group "Workflow",      "lib/glancer/workflow"
    add_group "Indexers",      "lib/glancer/indexer"
    add_group "Controllers",   "app/controllers"
    add_group "Models",        "app/models"
    add_group "Configuration", "lib/glancer/configuration.rb"

    minimum_coverage 80
    track_files "lib/**/*.rb"
  end
end

require "glancer"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = :random
  Kernel.srand config.seed
end
