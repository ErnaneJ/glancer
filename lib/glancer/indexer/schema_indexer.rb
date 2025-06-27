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

      def split_into_chunks(text, max_length = 1000)
        text.scan(/.{1,#{max_length}}/m)
      end
    end
  end
end
