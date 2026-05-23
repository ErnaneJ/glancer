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

require "glancer/utils/logger" # Glancer::Utils::Logger
require "glancer/utils/markdown_helper" # Glancer::Utils::MarkdownHelper
require "glancer/utils/result_formatter" # Glancer::Utils::ResultFormatter
require "glancer/utils/table_stats" # Glancer::Utils::TableStats
require "glancer/utils/transaction" # Glancer::Utils::Transaction

require "glancer/engine" # Glancer::Engine

require "glancer/indexer" # Glancer::Indexer
require "glancer/indexer/context_indexer" # Glancer::Indexer::ContextIndexer
require "glancer/indexer/model_indexer" # Glancer::Indexer::ModelIndexer
require "glancer/indexer/schema_indexer" # Glancer::Indexer::SchemaIndexer

require "glancer/retriever" # Glancer::Retriever

require "glancer/workflow" # Glancer::Workflow
require "glancer/workflow/builder" # Glancer::Workflow::Builder
require "glancer/workflow/cache" # Glancer::Workflow::Cache
require "glancer/workflow/executor" # Glancer::Workflow::Executor
require "glancer/workflow/prompt_builder" # Glancer::Workflow::PromptBuilder
require "glancer/workflow/sql_extractor" # Glancer::Workflow::SQLExtractor
require "glancer/workflow/sql_sanitizer" # Glancer::Workflow::SQLSanitizer
require "glancer/workflow/sql_validator" # Glancer::Workflow::SQLValidator
require "glancer/workflow/llm" # Glancer::Workflow::LLM
require "glancer/workflow/ar_prompt_builder" # Glancer::Workflow::ARPromptBuilder
require "glancer/workflow/ar_extractor" # Glancer::Workflow::ARExtractor
require "glancer/workflow/ar_sanitizer" # Glancer::Workflow::ARSanitizer
require "glancer/workflow/ar_executor" # Glancer::Workflow::ARExecutor

require "glancer/chart_analyzer" # Glancer::ChartAnalyzer
