namespace :glancer do
  desc "Show current Glancer and RubyLLM versions"
  task :version do
    puts "📦 Glancer version: #{Glancer::VERSION}"
  end

  namespace :index do
    desc "Rebuild all Glancer indexes"
    task all: :environment do
      Glancer::Embedding.where(source_type: "schema").delete_all
      Glancer::Embedding.where(source_type: "models").delete_all
      Glancer::Embedding.where(source_type: "context").delete_all

      Glancer::Indexer.rebuild_all!
      puts "✅ All indexes rebuilt!"
    end

    desc "Rebuild schema index only"
    task schema: :environment do
      Glancer::Embedding.where(source_type: "schema").delete_all
      chunks = Glancer::Indexer::SchemaIndexer.index!
      Glancer::Retriever.store_documents(chunks)
      puts "✅ Schema index rebuilt!"
    end

    desc "Rebuild models index only"
    task models: :environment do
      Glancer::Embedding.where(source_type: "models").delete_all
      chunks = Glancer::Indexer::ModelIndexer.index!
      Glancer::Retriever.store_documents(chunks)
      puts "✅ Models index rebuilt!"
    end

    desc "Rebuild context index only"
    task context: :environment do
      Glancer::Embedding.where(source_type: "context").delete_all
      chunks = Glancer::Indexer::ContextIndexer.index!
      Glancer::Retriever.store_documents(chunks)
      puts "✅ Context index rebuilt!"
    end
  end
end
