# frozen_string_literal: true

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

        if content.lines.first&.strip == "--glancer-ignore"
          Glancer::Utils::Logger.info("Indexer::ContextIndexer",
                                      "Context file marked with --glancer-ignore, skipping indexing.")
          return []
        end

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
        Glancer::Utils::Logger.error("Indexer::ContextIndexer",
                                     "Failed to index context: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Indexer::ContextIndexer", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error, "Context indexing failed: #{e.message}"
      end

      def split_into_chunks(text)
        size = Glancer.configuration.chunk_size
        overlap = Glancer.configuration.chunk_overlap
        chunks = []
        start = 0
        while start < text.length
          chunks << text[start, size]
          start += size - overlap
        end
        chunks
      end
    end
  end
end
