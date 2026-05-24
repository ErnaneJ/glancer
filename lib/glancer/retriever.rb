# frozen_string_literal: true

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

        vector = RubyLLM.embed(
          chunk,
          model: Glancer.configuration.resolved_embedding_model,
          provider: Glancer.configuration.resolved_embedding_provider,
          assume_model_exists: true
        ).vectors

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
      raise Glancer::Error, "Document storage failed: #{e.message}"
    end

    def search(query)
      Glancer::Utils::Logger.info("Retriever", "Searching for top #{Glancer.configuration.k} results...")

      query_embedding = RubyLLM.embed(
        query,
        model: Glancer.configuration.resolved_embedding_model,
        provider: Glancer.configuration.resolved_embedding_provider,
        assume_model_exists: true
      ).vectors

      # @TODO Postgres with native search?
      perform_ruby_search(query_embedding)
    end

    def perform_ruby_search(query_embedding)
      results = Glancer::Embedding.all.map do |record|
        # Calculate similarity between query and stored document
        score = cosine_similarity(query_embedding, record.embedding)
        weighted_score = score * weight_for(record.source_type)

        { record: record, score: weighted_score }
      end

      sorted = results.sort_by { |r| -r[:score] }

      # Filter by min_score threshold
      top_matches = sorted
                    .select { |r| r[:score] >= Glancer.configuration.min_score }
                    .first(Glancer.configuration.k)

      # Fallback: if nothing passes the threshold, use best available results so the
      # LLM always has some schema context rather than generating blind code.
      if top_matches.empty? && sorted.any?
        top_matches = sorted.first(Glancer.configuration.k)
        Glancer::Utils::Logger.warn("Retriever",
                                    "No results above min_score (#{Glancer.configuration.min_score}); " \
                                    "using top #{top_matches.size} result(s) as fallback")
      end

      top_matches = top_matches.map do |r|
        r[:record].tap do |record|
          record.define_singleton_method(:score) { r[:score] }
        end
      end

      Glancer::Utils::Logger.info("Retriever", "Found #{top_matches.size} relevant document(s)")
      top_matches
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
