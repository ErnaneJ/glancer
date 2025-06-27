module Glancer
  module Indexer
    module ModelIndexer
      module_function

      def index!
        puts("[Glancer::Indexer::ModelIndexer] Indexing models...")
        model_files = Dir[Rails.root.join("app/models/**/*.rb")]

        model_files.flat_map do |file|
          content = File.read(file)
          split_into_chunks(content).map do |chunk|
            {
              content: chunk,
              source_type: "model",
              source_path: file
            }
          end
        end
      end

      def split_into_chunks(text, max_length = 1000)
        text.scan(/.{1,#{max_length}}/m)
      end
    end
  end
end
