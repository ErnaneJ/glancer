require_relative "indexer/schema_indexer"
require_relative "indexer/model_indexer"
require_relative "indexer/context_indexer"

module Glancer
  module Indexer
    module_function

    def rebuild_all!
      puts("[Glancer::Indexer] Starting full index rebuild...")

      Glancer::Embedding.delete_all

      puts("[Glancer::Indexer] Rebuilding all indexes...")

      chunks = []

      chunks += SchemaIndexer.index! if Glancer.configuration.schema_permission

      chunks += ModelIndexer.index! if Glancer.configuration.models_permission

      chunks += ContextIndexer.index! if Glancer.configuration.context_file_path

      puts("[Glancer::Indexer] Rebuilding complete. #{chunks.size} chunks indexed.")

      Retriever.store_documents(chunks)

      chunks
    end
  end
end
