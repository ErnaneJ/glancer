# frozen_string_literal: true

require "glancer/version"
require "glancer/configuration"

module Glancer
  class Error < StandardError; end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end

require "glancer/engine"

require "glancer/indexer"
require "glancer/indexer/context_indexer"
require "glancer/indexer/model_indexer"
require "glancer/indexer/schema_indexer"
require "glancer/retriever"
