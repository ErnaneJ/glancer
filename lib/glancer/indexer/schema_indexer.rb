module Glancer
  module Indexer
    module SchemaIndexer
      module_function

      def index!
        puts("[Glancer::Indexer::SchemaIndexer] Indexing schema...")
        schema_file = Rails.root.join("db/schema.rb")
        return [] unless File.exist?(schema_file)

        content = File.read(schema_file)
        split_into_chunks(content).map do |chunk|
          {
            content: chunk,
            source_type: "schema",
            source_path: schema_file.to_s
          }
        end
      end

      def split_into_chunks(schema_text)
        schema_text.split(/^  create_table /).map do |chunk|
          next if chunk.strip.empty?

          "create_table #{chunk.strip}"
        end.compact
      end
    end
  end
end
