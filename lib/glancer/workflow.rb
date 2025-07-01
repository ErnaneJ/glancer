module Glancer
  module Workflow
    def self.run(question, cache: true)
      Glancer::Utils::Logger.info("Workflow", "Running workflow for question: #{question.inspect}")

      if cache && (cached = Workflow::Cache.fetch(question))
        Glancer::Utils::Logger.info("Workflow", "Using cached result for question: #{question.inspect}")
        return cached.merge(from_cache: true)
      end

      Glancer::Utils::Logger.info("Workflow", "No cached result. Performing retrieval and SQL generation...")

      embeddings = Retriever.search(question)
      Glancer::Utils::Logger.debug("Workflow", "Retrieved #{embeddings.size} relevant document(s) for context")

      sql = Workflow::Builder.build_sql(question, embeddings)
      Glancer::Utils::Logger.debug("Workflow", "Generated raw SQL:\n#{sql}")

      sql = Workflow::SQLExtractor.extract(sql)
      Glancer::Utils::Logger.debug("Workflow", "Extracted SQL:\n#{sql}")

      Workflow::SQLSanitizer.ensure_safe!(sql)
      Workflow::SQLValidator.validate_tables_exist!(sql)

      raw_data = Workflow::Executor.execute(sql, original_question: question)

      result = {
        question: question,
        sql: sql,
        raw_data: Glancer::Utils::ResultFormatter.normalize(raw_data),
        sources: embeddings.map do |e|
          {
            id: e.id,
            type: e.source_type,
            path: e.source_path,
            score: e.score
          }
        end
      }

      if cache
        Workflow::Cache.write(question, result)
        Glancer::Utils::Logger.info("Workflow", "Result cached for question: #{question.inspect}")
      end

      result
    rescue StandardError => e
      Glancer::Utils::Logger.error("Workflow", "Workflow execution failed: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Workflow", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error.new("Workflow failed: #{e.message}"), cause: e
    end
  end
end
