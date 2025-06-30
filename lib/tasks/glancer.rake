namespace :glancer do
  desc "Show current Glancer and RubyLLM versions"
  task :version do
    puts "\n\e[36m✱ glancer@v#{Glancer::VERSION}\e[0m\n"
    puts
  end

  namespace :index do
    desc "Rebuild all Glancer indexes"
    task all: :environment do
      existing = Glancer::Embedding.count
      if existing > 0
        puts "\n\e[33m✱ There are currently #{existing} embeddings stored.\e[0m"
        puts "\e[31m└→ This operation will delete all existing embeddings and reindex everything.\e[0m"
      end

      Glancer::Utils::Transaction.with_transaction do
        Glancer::Embedding.where(source_type: %w[schema models context]).delete_all

        Glancer::Utils::Logger.with_debug_logs do
          Glancer::Indexer.rebuild_all!
        end

        puts "\e[32m✔ All indexes rebuilt!\e[0m"
      end
    end

    desc "Rebuild schema index only"
    task schema: :environment do
      if confirm_rebuild?(:schema)
        Glancer::Utils::Transaction.with_transaction do
          # Glancer::Embedding.where(source_type: "schema").delete_all

          # Glancer::Utils::Logger.with_debug_logs do
          #   chunks = Glancer::Indexer::SchemaIndexer.index!
          #   Glancer::Retriever.store_documents(chunks)
          # end

          puts "\e[32m✔ Schema index rebuilt!\e[0m"
        end
      end
    end

    desc "Rebuild models index only"
    task models: :environment do
      if confirm_rebuild?(:models)
        Glancer::Utils::Transaction.with_transaction do
          Glancer::Embedding.where(source_type: "models").delete_all

          Glancer::Utils::Logger.with_debug_logs do
            chunks = Glancer::Indexer::ModelIndexer.index!
            Glancer::Retriever.store_documents(chunks)
          end

          puts "\e[32m✔ Models index rebuilt!\e[0m"
        end
      end
    end

    desc "Rebuild context index only"
    task context: :environment do
      if confirm_rebuild?(:context)
        Glancer::Utils::Transaction.with_transaction do
          Glancer::Embedding.where(source_type: "context").delete_all

          Glancer::Utils::Logger.with_debug_logs do
            chunks = Glancer::Indexer::ContextIndexer.index!
            Glancer::Retriever.store_documents(chunks)
          end

          puts "\e[32m✔ Context index rebuilt!\e[0m"
        end
      end
    end
  end

  def confirm_rebuild?(type)
    existing = Glancer::Embedding.where(source_type: type.to_s)
    if existing.exists?
      last = existing.order(created_at: :desc).first.created_at
      puts "\n\e[33m✱ Existing #{existing.count} '#{type}' embeddings found. Last updated: #{last.strftime("%Y-%m-%d %H:%M:%S")}.\e[0m"
      print "\e[31m└→ Do you want to delete and reindex? [y/N]: \e[0m"
      input = STDIN.gets.strip.upcase

      puts "\n\e[31m✖ Operation cancelled.\e[0m\n" unless input == "Y"

      return input == "Y"
    end
    true
  rescue Interrupt
    puts "\n\n\e[31m✖ Operation cancelled\e[0m\n"
    false
  rescue StandardError => e
    puts "\n\n\e[31m✖ Error: #{e.message}\e[0m\n"
    false
  end
end
