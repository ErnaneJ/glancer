module Glancer
  module Indexer
    module SchemaIndexer
      module_function

      def index!
        Glancer::Utils::Logger.info("Indexer::SchemaIndexer", "Starting schema indexing...")

        schema_file = Rails.root.join("db/schema.rb")

        unless File.exist?(schema_file)
          Glancer::Utils::Logger.warn("Indexer::SchemaIndexer", "Schema file not found at: #{schema_file}")
          return []
        end

        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Reading schema file from: #{schema_file}")

        content = File.read(schema_file)
        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Read #{content.bytesize} bytes from schema file")

        chunks = split_into_chunks(content)
        Glancer::Utils::Logger.info("Indexer::SchemaIndexer", "Found #{chunks.size} table definition(s) in schema")

        indexed_chunks = chunks.map do |chunk|
          table_name = extract_table_name(chunk)
          if table_name
            Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Indexed table: #{table_name}")
            {
              content: chunk,
              source_type: "schema",
              source_path: "#{schema_file}##{table_name}"
            }
          else
            Glancer::Utils::Logger.warn("Indexer::SchemaIndexer", "Could not extract table name from chunk")
            nil
          end
        end.compact

        Glancer::Utils::Logger.info("Indexer::SchemaIndexer",
                                    "Completed schema indexing. Total indexed tables: #{indexed_chunks.size}")

        indexed_chunks
      rescue StandardError => e
        Glancer::Utils::Logger.error("Indexer::SchemaIndexer", "Schema indexing failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Indexer::SchemaIndexer", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Schema indexing failed: #{e.message}"), cause: e
      end

      def split_into_chunks(schema_text)
        schema_text.split(/^  create_table /).map do |chunk|
          next if chunk.strip.empty?

          "create_table #{chunk.strip}"
        end.compact
      end

      def extract_table_name(chunk)
        chunk[/create_table ["']?([a-zA-Z0-9_]+)["']?/, 1]
      end
    end
  end
end
