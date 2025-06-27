module Glancer
  module Indexer
    module ContextIndexer
      module_function

      def index!
        puts("[Glancer::Indexer::ContextIndexer] Indexing context...")
        path = Glancer.configuration.context_file_path
        return [] if path.blank? || !File.exist?(path)

        content = File.read(path)
        split_into_chunks(content).map do |chunk|
          {
            content: chunk,
            source_type: "context",
            source_path: path
          }
        end
      end

      def split_into_chunks(text, max_length = 1000)
        text.scan(/.{1,#{max_length}}/m)
      end
    end
  end
end
