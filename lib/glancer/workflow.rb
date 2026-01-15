module Glancer
  module Workflow
    def self.run(chat_id, question, cache: true)
      Glancer::Utils::Logger.info("Workflow",
                                  "Running workflow for chat_id: #{chat_id.inspect}, question: #{question.inspect}, cache: #{cache}")

      if cache && (cached = Workflow::Cache.fetch(question))
        Glancer::Utils::Logger.info("Workflow", "Using cached result for question: #{question.inspect}")
        return cached.merge(from_cache: true)
      end

      chat = Glancer::Chat.find(chat_id)
      history = chat.messages.order(created_at: :desc).limit(6).reverse

      Glancer::Utils::Logger.info("Workflow", "No cached result. Performing retrieval and SQL generation...")

      embeddings = Retriever.search(question)
      Glancer::Utils::Logger.debug("Workflow", "Retrieved #{embeddings.size} relevant document(s) for context")

      sql = Workflow::Builder.build_sql(question, embeddings, history: history)
      Glancer::Utils::Logger.debug("Workflow", "Generated raw SQL:\n#{sql}")

      sql = Workflow::SQLExtractor.extract(sql)
      Glancer::Utils::Logger.debug("Workflow", "Extracted SQL:\n#{sql}")

      Workflow::SQLSanitizer.ensure_safe!(sql)
      Workflow::SQLValidator.validate_tables_exist!(sql)

      raw_data = Workflow::Executor.execute(sql, original_question: question)

      if raw_data.is_a?(Hash) && raw_data[:error]
        explanation = Glancer::Workflow::LLM.explain_error(question, raw_data[:message], raw_data[:last_sql])

        return {
          question: question,
          content: explanation,
          sql: raw_data[:last_sql],
          successful: false
        }
      end

      result = {
        question: question,
        content: Glancer::Workflow::LLM.humanized_response(question, raw_data, sql),
        sql: sql,
        successful: true,
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
