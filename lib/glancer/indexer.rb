require_relative "indexer/schema_indexer"
require_relative "indexer/model_indexer"
require_relative "indexer/context_indexer"

module Glancer
  module Indexer
    module_function

    def rebuild_all!
      Glancer::Utils::Logger.info("Indexer", "Starting full index rebuild...")

      chunks = []

      if Glancer.configuration.schema_permission
        Glancer::Utils::Logger.info("Indexer", "Indexing schema (enabled by configuration)...")
        chunks += SchemaIndexer.index!
      else
        Glancer::Utils::Logger.debug("Indexer", "Schema indexing is disabled in configuration.")
      end

      if Glancer.configuration.models_permission
        Glancer::Utils::Logger.info("Indexer", "Indexing models (enabled by configuration)...")
        chunks += ModelIndexer.index!
      else
        Glancer::Utils::Logger.debug("Indexer", "Model indexing is disabled in configuration.")
      end

      if Glancer.configuration.context_file_path
        Glancer::Utils::Logger.info("Indexer", "Indexing context file (path configured)...")
        chunks += ContextIndexer.index!
      else
        Glancer::Utils::Logger.debug("Indexer", "No context file path configured. Skipping context indexing.")
      end

      Glancer::Utils::Logger.info("Indexer", "Indexing completed. Total chunks: #{chunks.size}")

      Glancer::Utils::Logger.debug("Indexer", "Storing documents into retriever...")
      Retriever.store_documents(chunks)
      Glancer::Utils::Logger.info("Indexer", "Documents stored successfully.")

      chunks
    rescue StandardError => e
      Glancer::Utils::Logger.error("Indexer", "Index rebuilding failed: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Indexer", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error.new("Index rebuilding failed: #{e.message}"), cause: e
    end
  end
end
