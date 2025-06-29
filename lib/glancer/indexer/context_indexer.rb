module Glancer
  module Indexer
    module ContextIndexer
      module_function

      def index!
        Glancer::Utils::Logger.info("Indexer::ContextIndexer", "Starting context indexing...")

        path = Glancer.configuration.context_file_path

        if path.nil? || !File.exist?(path)
          Glancer::Utils::Logger.error("Indexer::ContextIndexer", "Context file not found at path: #{path.inspect}")
          raise Glancer::Error, "Context file not found. Expected at: #{path.inspect}"
        end

        Glancer::Utils::Logger.debug("Indexer::ContextIndexer", "Reading context file from: #{path}")

        content = File.read(path)
        Glancer::Utils::Logger.debug("Indexer::ContextIndexer", "Read #{content.bytesize} bytes from context file")

        chunks = split_into_chunks(content)
        Glancer::Utils::Logger.info("Indexer::ContextIndexer", "Split content into #{chunks.size} chunk(s)")

        chunks.map do |chunk|
          {
            content: chunk,
            source_type: "context",
            source_path: path
          }
        end
      rescue StandardError => e
        Glancer::Utils::Logger.error("Indexer::ContextIndexer", "Failed to index context: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Indexer::ContextIndexer", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Context indexing failed: #{e.message}"), cause: e
      end

      def split_into_chunks(text, max_length = 1000)
        text.scan(/.{1,#{max_length}}/m)
      end
    end
  end
end
