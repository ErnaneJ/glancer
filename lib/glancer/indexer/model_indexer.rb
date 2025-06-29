module Glancer
  module Indexer
    module ModelIndexer
      module_function

      def index!
        Glancer::Utils::Logger.info("Indexer::ModelIndexer", "Starting model indexing...")

        model_files = Dir[Rails.root.join("app/models/**/*.rb")]

        if model_files.empty?
          Glancer::Utils::Logger.warn("Indexer::ModelIndexer", "No model files found for indexing.")
          return []
        end

        Glancer::Utils::Logger.info("Indexer::ModelIndexer", "Found #{model_files.size} model file(s)")

        all_chunks = []

        model_files.each do |file|
          Glancer::Utils::Logger.debug("Indexer::ModelIndexer", "Reading model file: #{file}")

          content = File.read(file)
          Glancer::Utils::Logger.debug("Indexer::ModelIndexer", "Read #{content.bytesize} bytes from #{file}")

          chunks = split_into_chunks(content)
          Glancer::Utils::Logger.debug("Indexer::ModelIndexer", "Split into #{chunks.size} chunk(s)")

          all_chunks.concat(
            chunks.map do |chunk|
              {
                content: chunk,
                source_type: "model",
                source_path: file
              }
            end
          )
        end

        Glancer::Utils::Logger.info("Indexer::ModelIndexer", "Completed indexing. Total chunks: #{all_chunks.size}")

        all_chunks
      rescue StandardError => e
        Glancer::Utils::Logger.error("Indexer::ModelIndexer", "Model indexing failed: #{e.class} - #{e.message}")
        Glancer::Utils::Logger.debug("Indexer::ModelIndexer", "Backtrace:\n#{e.backtrace.join("\n")}")
        raise Glancer::Error.new("Model indexing failed: #{e.message}"), cause: e
      end

      def split_into_chunks(text, max_length = 1000)
        text.scan(/.{1,#{max_length}}/m)
      end
    end
  end
end
