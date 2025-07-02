require "ruby_llm"

module Glancer
  module Retriever
    module_function

    def store_documents(chunks_with_metadata)
      Glancer::Utils::Logger.info("Retriever", "Storing #{chunks_with_metadata.size} document chunk(s)...")

      chunks_with_metadata.each_with_index do |data, idx|
        chunk = data[:content]
        preview = chunk[0..50].gsub(/\s+/, " ").strip

        Glancer::Utils::Logger.debug("Retriever",
                                     "Embedding chunk ##{idx + 1} (#{data[:source_type]} - #{data[:source_path]}): '#{preview}...'")

        vector = RubyLLM.embed(chunk, provider: Glancer.configuration.llm_provider).vectors

        Glancer::Utils::Logger.debug("Retriever",
                                     "Vector size: #{vector.size}, example values: #{vector.first(5).inspect}")

        Glancer::Embedding.create!(
          content: chunk,
          embedding: vector,
          source_type: data[:source_type],
          source_path: data[:source_path]
        )

        Glancer::Utils::Logger.info("Retriever",
                                    "Stored chunk ##{idx + 1} from #{data[:source_type]}: #{data[:source_path]}")
      end

      Glancer::Utils::Logger.info("Retriever", "All chunks stored successfully.")
    rescue StandardError => e
      Glancer::Utils::Logger.error("Retriever", "Failed to store document chunks: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Retriever", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error.new("Document storage failed: #{e.message}"), cause: e
    end

    def search(query)
      Glancer::Utils::Logger.info("Retriever",
                                  "Searching for top #{Glancer.configuration.k} results with min_score: #{Glancer.configuration.min_score}")
      Glancer::Utils::Logger.debug("Retriever", "Query: #{query}")

      query_embedding = RubyLLM.embed(query, provider: Glancer.configuration.llm_provider).vectors

      results = Glancer::Embedding.all.map do |record|
        score = cosine_similarity(query_embedding, record.embedding)
        weighted_score = score * weight_for(record.source_type)

        Glancer::Utils::Logger.debug("Retriever",
                                     "Scored record from #{record.source_type} (#{record.source_path}) with raw=#{score.round(4)} weighted=#{weighted_score.round(4)}")

        { record: record, score: weighted_score }
      end

      top_matches = results
                    .select { |r| r[:score] >= Glancer.configuration.min_score }
                    .sort_by { |r| -r[:score] }
                    .first(Glancer.configuration.k)
                    .map do |r|
        r[:record].tap do |record|
          record.define_singleton_method(:score) { r[:score] }
        end
      end

      Glancer::Utils::Logger.info("Retriever", "Found #{top_matches.size} matching document(s)")

      top_matches
    rescue StandardError => e
      Glancer::Utils::Logger.error("Retriever", "Search failed: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Retriever", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error.new("Search failed: #{e.message}"), cause: e
    end

    def weight_for(source_type)
      case source_type
      when "schema"  then Glancer.configuration.schema_documents_weight
      when "context" then Glancer.configuration.context_documents_weight
      when "models"  then Glancer.configuration.models_documents_weight
      else 1.0
      end
    end

    def cosine_similarity(vec1, vec2)
      dot = vec1.zip(vec2).map { |a, b| a * b }.sum
      mag1 = Math.sqrt(vec1.sum { |x| x**2 })
      mag2 = Math.sqrt(vec2.sum { |x| x**2 })
      return 0.0 if mag1.zero? || mag2.zero?

      dot / (mag1 * mag2)
    end
  end
end
