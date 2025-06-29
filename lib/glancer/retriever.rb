require "ruby_llm"

module Glancer
  module Retriever
    module_function

    def store_documents(chunks_with_metadata)
      chunks_with_metadata.each do |data|
        chunk = data[:content]
        puts("[Glancer::Retriever] Processing chunk: #{chunk[0..50]}...")
        vector = RubyLLM.embed(chunk, provider: Glancer.configuration.llm_provider).vectors
        Glancer::Embedding.create!(
          content: chunk,
          embedding: vector,
          source_type: data[:source_type],
          source_path: data[:source_path]
        )
        puts("[Glancer::Retriever] Stored chunk from #{data[:source_type]}: #{data[:source_path]}")
      end
    end

    def search(query, k: 5, min_score: 0.6)
      query_embedding = RubyLLM.embed(query, provider: Glancer.configuration.llm_provider).vectors

      Glancer::Embedding.all
                        .map do |record|
        score = cosine_similarity(query_embedding, record.embedding)
        weighted_score = score * weight_for(record.source_type)

        { record: record, score: weighted_score }
      end
        .select { |r| r[:score] >= min_score }
                        .sort_by { |r| -r[:score] }
                        .first(k)
                        .map do |r|
        r[:record].tap do |record|
          record.define_singleton_method(:score) { r[:score] }
        end
      end
    end

    def weight_for(source_type)
      case source_type
      when "schema"  then 1.3
      when "context" then 1.2
      when "models"  then 1.1
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
