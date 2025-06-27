namespace :glancer do
  namespace :install do
    desc "Copy Glancer engine migrations into the main app"
    task migrations: :environment do
      puts "🔄 Copying Glancer migrations..."

      source = File.expand_path("../../db/migrate", __dir__)
      destination = Rails.root.join("db/migrate")

      FileUtils.mkdir_p(destination) unless File.exist?(destination)

      Dir.glob("#{source}/*.rb").each do |file|
        filename = File.basename(file)
        migration_name = filename.sub(/^\d+_/, "").gsub(".rb", "")
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        new_filename = "#{timestamp}_#{migration_name}.rb"
        target_path = File.join(destination, new_filename)

        if File.exist?(target_path)
          puts "⚠️  Skipping #{new_filename} (already exists)"
        else
          FileUtils.cp(file, target_path)
          puts "✅ Copied: #{new_filename}"
          sleep(1) # Garante timestamp único
        end
      end
    end
  end
  namespace :index do
    desc "Rebuild all Glancer indexes"
    task rebuild_all: :environment do
      Glancer::Embedding.where(source_type: "schema").delete_all
      Glancer::Embedding.where(source_type: "models").delete_all
      Glancer::Embedding.where(source_type: "context").delete_all

      Glancer::Indexer.rebuild_all!
      puts "✅ All indexes rebuilt!"
    end

    desc "Rebuild schema index only"
    task rebuild_schema: :environment do
      Glancer::Embedding.where(source_type: "schema").delete_all
      chunks = Glancer::Indexer::SchemaIndexer.index!
      Glancer::Retriever.store_documents(chunks)
      puts "✅ Schema index rebuilt!"
    end

    desc "Rebuild models index only"
    task rebuild_models: :environment do
      Glancer::Embedding.where(source_type: "models").delete_all
      chunks = Glancer::Indexer::ModelIndexer.index!
      Glancer::Retriever.store_documents(chunks)
      puts "✅ Models index rebuilt!"
    end

    desc "Rebuild context index only"
    task rebuild_context: :environment do
      Glancer::Embedding.where(source_type: "context").delete_all
      chunks = Glancer::Indexer::ContextIndexer.index!
      Glancer::Retriever.store_documents(chunks)
      puts "✅ Context index rebuilt!"
    end
  end
end
