# frozen_string_literal: true

module Glancer
  module Workflow
    def self.run(chat_id, question, cache: true)
      Glancer::Utils::Logger.info("Workflow",
                                  "Running workflow for chat_id: #{chat_id.inspect}, " \
                                  "question: #{question.inspect}, " \
                                  "mode: #{Glancer.configuration.query_mode}, cache: #{cache}")

      if cache && (cached = Workflow::Cache.fetch(question))
        Glancer::Utils::Logger.info("Workflow", "Using cached result for question: #{question.inspect}")
        return cached.merge(from_cache: true)
      end

      chat = Glancer::Chat.find(chat_id)
      history = chat.messages.order(created_at: :desc).limit(Glancer.configuration.history_limit).reverse

      embeddings = Retriever.search(question)
      Glancer::Utils::Logger.debug("Workflow", "Retrieved #{embeddings.size} relevant document(s) for context")

      result = if Glancer.configuration.query_mode == :activerecord
                 run_activerecord(question, embeddings, history)
               else
                 run_sql(question, embeddings, history)
               end

      if cache && result[:successful]
        Workflow::Cache.write(question, result)
        Glancer::Utils::Logger.info("Workflow", "Result cached for question: #{question.inspect}")
      end

      result
    rescue StandardError => e
      Glancer::Utils::Logger.error("Workflow", "Workflow execution failed: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Workflow", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error, "Workflow failed: #{e.message}"
    end

    def self.run_sql(question, embeddings, history)
      Glancer::Utils::Logger.info("Workflow", "Running SQL code generation mode...")

      sql = Workflow::Builder.build_sql(question, embeddings, history: history)
      Glancer::Utils::Logger.debug("Workflow", "Generated raw SQL:\n#{sql}")

      sql = Workflow::SQLExtractor.extract(sql)
      Glancer::Utils::Logger.debug("Workflow", "Extracted SQL:\n#{sql}")

      Workflow::SQLSanitizer.ensure_safe!(sql)

      begin
        Workflow::SQLValidator.validate_tables_exist!(sql)
      rescue Glancer::Error => e
        Glancer::Utils::Logger.warn("Workflow", "Table validation failed: #{e.message}. Returning friendly response.")
        explanation = Glancer::Workflow::LLM.explain_missing_tables(question, e.message)
        return {
          question: question,
          content: explanation,
          code: sql,
          code_type: "sql",
          successful: false
        }
      end

      raw_data = Workflow::Executor.execute(sql, original_question: question)

      if raw_data.is_a?(Hash) && raw_data[:error]
        explanation = Glancer::Workflow::LLM.explain_error(question, raw_data[:message], raw_data[:last_code])
        return {
          question: question,
          content: explanation,
          code: raw_data[:last_code],
          code_type: "sql",
          successful: false
        }
      end

      {
        question: question,
        content: Glancer::Workflow::LLM.humanized_response(question, raw_data, sql),
        code: sql,
        code_type: "sql",
        successful: true,
        sources: embeddings.map { |e| { id: e.id, type: e.source_type, path: e.source_path, score: e.score } }
      }
    end
    private_class_method :run_sql

    def self.run_activerecord(question, embeddings, history)
      Glancer::Utils::Logger.info("Workflow", "Running ActiveRecord mode...")

      code = Workflow::Builder.build_ar_code(question, embeddings, history: history)
      Glancer::Utils::Logger.debug("Workflow", "Generated raw AR code:\n#{code}")

      code = Workflow::ARExtractor.extract(code)
      Glancer::Utils::Logger.debug("Workflow", "Extracted AR code:\n#{code}")

      Workflow::ARSanitizer.ensure_safe!(code)

      raw_data = Workflow::ARExecutor.execute(code, original_question: question)

      if raw_data.is_a?(Hash) && raw_data[:error]
        explanation = Glancer::Workflow::LLM.explain_error(
          question, raw_data[:message], raw_data[:last_code], mode: :activerecord
        )
        return {
          question: question,
          content: explanation,
          code: raw_data[:last_code],
          code_type: "activerecord",
          successful: false
        }
      end

      {
        question: question,
        content: Glancer::Workflow::LLM.humanized_response(question, raw_data, code, mode: :activerecord),
        code: code,
        code_type: "activerecord",
        successful: true,
        sources: embeddings.map { |e| { id: e.id, type: e.source_type, path: e.source_path, score: e.score } }
      }
    end
    private_class_method :run_activerecord
  end
end
