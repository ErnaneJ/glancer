# frozen_string_literal: true

module Glancer
  module Workflow
    def self.run(chat_id, question, cache: true, &status_callback)
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

      enrichment_enabled = Glancer.configuration.query_enrichment_enabled
      adapter            = Glancer.configuration.query_mode

      status_callback&.call(:enriching) if enrichment_enabled
      effective_question = enrich_question(question, history, adapter: adapter)

      status_callback&.call(:retrieving_context)
      embeddings = Retriever.search(effective_question)
      Glancer::Utils::Logger.debug("Workflow", "Retrieved #{embeddings.size} relevant document(s) for context")

      result = if adapter == :activerecord
                 run_activerecord(question, effective_question, embeddings, history, status_callback)
               else
                 run_sql(question, effective_question, embeddings, history, status_callback)
               end

      # Always persist the enriched question so the info panel can show it on every message
      result[:enriched_question] = effective_question if enrichment_enabled

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

    def self.enrich_question(question, history = [], adapter: nil)
      return question unless Glancer.configuration.query_enrichment_enabled

      Glancer::Utils::Logger.info("Workflow", "Enriching question before retrieval...")
      table_names = Glancer::Workflow::QueryEnricher.known_table_names
      enriched    = Glancer::Workflow::QueryEnricher.enrich(question, table_names, history: history,
                                                                                   adapter: adapter)
      Glancer::Utils::Logger.info("Workflow", "Enriched question: #{enriched.inspect}")
      enriched
    rescue StandardError => e
      Glancer::Utils::Logger.warn("Workflow", "Question enrichment failed, using original: #{e.message}")
      question
    end
    private_class_method :enrich_question

    def self.run_sql(question, effective_question, embeddings, history, status_callback = nil)
      Glancer::Utils::Logger.info("Workflow", "Running SQL code generation mode...")

      status_callback&.call(:generating_code)
      sql = Workflow::Builder.build_sql(effective_question, embeddings, history: history)
      Glancer::Utils::Logger.debug("Workflow", "Generated raw SQL:\n#{sql}")

      sql = Workflow::SQLExtractor.extract(sql)
      Glancer::Utils::Logger.debug("Workflow", "Extracted SQL:\n#{sql}")

      Workflow::SQLSanitizer.ensure_safe!(sql)

      begin
        status_callback&.call(:validating)
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

      status_callback&.call(:executing)
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

      status_callback&.call(:humanizing)
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

    def self.run_activerecord(question, effective_question, embeddings, history, status_callback = nil)
      Glancer::Utils::Logger.info("Workflow", "Running ActiveRecord mode...")

      status_callback&.call(:generating_code)
      code = Workflow::Builder.build_ar_code(effective_question, embeddings, history: history)
      Glancer::Utils::Logger.debug("Workflow", "Generated raw AR code:\n#{code}")

      code = Workflow::ARExtractor.extract(code)
      Glancer::Utils::Logger.debug("Workflow", "Extracted AR code:\n#{code}")

      Workflow::ARSanitizer.ensure_safe!(code)

      status_callback&.call(:executing)
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

      status_callback&.call(:humanizing)
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
