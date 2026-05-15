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
    add_filter "/lib/glancer/version.rb" # loaded by bundler before SimpleCov starts

    add_group "Workflow",      "lib/glancer/workflow"
    add_group "Indexers",      "lib/glancer/indexer"
    add_group "Controllers",   "app/controllers"
    add_group "Models",        "app/models"
    add_group "Configuration", "lib/glancer/configuration.rb"

    minimum_coverage 80
    track_files "lib/**/*.rb"
  end
end

# Must load Rails BEFORE requiring glancer, because engine.rb inherits Rails::Engine
require "active_record"
require "active_record/railtie"
require "action_dispatch"
require "rails"

# Minimal Rails application — provides Rails.root and Rails.application.
# Do NOT call initialize! (avoids assets, LLM config, migration initializers).
module GlancerTestApp
  class Application < Rails::Application
    config.eager_load = false
    config.logger     = Logger.new(nil)
    config.active_support.deprecation = :silence
  end
end
GlancerTestApp::Application.new # sets Rails.application

# ApplicationRecord must exist BEFORE Glancer models are autoloaded.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

require "glancer"

# Rails 7.1+ removed the positional `serialize :attr, SomeClass` form in favour of
# keyword arguments.  The production Glancer::Embedding model uses the old two-arg
# form (`serialize :embedding, Array`).  We shim ActiveRecord::Base.serialize to
# translate the legacy positional argument into the correct keyword form so the
# model loads under Rails 7.2 without modifying production code.
#
# When the legacy coder is a type class (Array, Hash, …) Rails 7.2 expects it as
# `type:` with the default YAML coder, not as `coder:` (which would try to call
# Array.new with the wrong arguments).
module SerializeCompatShim
  TYPE_CLASSES = [Array, Hash, String, Integer, Float].freeze

  def serialize(attr_name, legacy_coder = nil, coder: nil, type: Object, **opts)
    if legacy_coder && coder.nil?
      if TYPE_CLASSES.include?(legacy_coder)
        # Old form: serialize :col, Array  →  coder: YAML, type: Array
        super(attr_name, type: legacy_coder, **opts)
      else
        # Old form: serialize :col, SomeCoder  →  coder: SomeCoder
        super(attr_name, coder: legacy_coder, type: type, **opts)
      end
    else
      super(attr_name, coder: coder, type: type, **opts)
    end
  end
end
ActiveRecord::Base.singleton_class.prepend(SerializeCompatShim)

# Explicitly require Glancer model files (the engine's autoloading is not active
# in the minimal test Rails application).
Dir[File.expand_path("../app/models/**/*.rb", __dir__)].sort.each { |f| require f }

# SQLite3 in-memory database for tests.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Suppress migration output.
ActiveRecord::Migration.verbose = false

# Create all tables used by Glancer.
load File.expand_path("support/schema.rb", __dir__)

# Silence Glancer logger during the test run.
Glancer.configure do |c|
  c.adapter        = :sqlite
  c.llm_provider   = :gemini
  c.llm_model      = "test-model"
  c.gemini_api_key = "test-api-key"
  c.log_verbosity  = :none
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.order = :random
  Kernel.srand config.seed

  config.before do
    # Clean DB between tests (order matters: child tables first).
    [Glancer::SqlVersion, Glancer::Audit, Glancer::Embedding,
     Glancer::Message, Glancer::Chat, Glancer::Setting].each(&:delete_all)

    # Clear the in-memory workflow cache.
    Glancer::Workflow::Cache.clear

    # Reset Glancer configuration to safe test defaults.
    Glancer.configuration = Glancer::Configuration.new.tap do |c|
      c.adapter        = :sqlite
      c.llm_provider   = :gemini
      c.llm_model      = "test-model"
      c.gemini_api_key = "test-api-key"
      c.log_verbosity  = :silent
    end
  end
end
