module Glancer
  module Workflow
    def self.run(question, cache: true)
      puts("[Glancer::Workflow] Running for question: #{question.inspect}")

      if cache && (cached = Workflow::Cache.fetch(question))
        puts("[Glancer::Workflow] Using cached result.")
        return cached.merge(from_cache: true)
      end

      embeddings = Retriever.search(question)
      context_docs = embeddings.map(&:content)

      sql = Workflow::Builder.build_sql(question, context_docs)
      sql = Workflow::SQLExtractor.extract(sql)

      Workflow::SQLSanitizer.ensure_safe!(sql)
      Workflow::SQLValidator.validate_tables_exist!(sql)

      raw_data = Workflow::Executor.execute(sql)

      result = {
        question: question,
        sql: sql,
        raw_data: raw_data,
        sources: embeddings.map { |e| { id: e.id, type: e.source_type, path: e.source_path } }
      }

      Workflow::Cache.write(question, result) if cache

      result
    end
  end
end
