# frozen_string_literal: true

module Glancer
  module Workflow
    class QueryEnricher
      PROMPT_TEMPLATE = <<~PROMPT
        You are a database query specification expert. Enrich the user's question into a precise technical specification that a code generator will use to produce correct %<adapter>s code.

        ## Available Tables
        %<tables>s

        %<schema_context>s%<history>s## User Question
        "%<question>s"

        ## Your Output
        Write a dense, unambiguous technical specification in English covering ALL applicable points below. Be concrete — use exact names, operators, and formats.

        **Model/Table**: State the exact model class (PascalCase for ActiveRecord, table name for SQL) involved. Resolve @mention shortcuts to their table names (e.g. @pages → Page model, pages table). Map natural-language synonyms ("records", "entries", "items") to the correct table.

        **Conditions**: Translate relative time expressions into explicit date arithmetic (e.g. "last 6 months" → `created_at >= 6.months.ago.beginning_of_month`). Name every column used in filters.

        **Aggregations**: Name the exact aggregate function and column (COUNT, SUM, AVG, GROUP BY). For time-based grouping, specify the format string (e.g. `TO_CHAR(created_at, 'MM/YYYY')` for month/year, `DATE_TRUNC('month', created_at)` for date truncation). PostgreSQL is the database.

        **Follow-up resolution**: Check RECENT CONVERSATION — if this is a follow-up question, carry forward the same model, columns, and filters from before. Resolve pronouns ("it", "them", "that result") explicitly using context.

        **Output shape**: Describe expected result structure (e.g. "one row per month: columns month as MM/YYYY string, count as integer"). If the result should be sorted, specify direction (chronological ASC unless stated otherwise).

        Output ONLY the specification. English. No code. No preamble. No explanations.
      PROMPT

      def self.enrich(question, table_names, history: [], adapter: nil)
        return question if table_names.empty?

        adapter_label    = adapter&.to_s == "activerecord" ? "ActiveRecord Ruby" : "SQL"
        history_block    = build_history_block(history)
        schema_ctx       = schema_context_for(question, table_names)

        prompt = format(
          PROMPT_TEMPLATE,
          adapter: adapter_label,
          tables: table_names.join(", "),
          schema_context: schema_ctx,
          history: history_block,
          question: question
        )

        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_enrichment_provider,
          model: Glancer.configuration.resolved_enrichment_model,
          assume_model_exists: true
        )

        enriched = chat.ask(prompt).content.to_s.strip
        enriched.presence || question
      rescue StandardError => e
        Glancer::Utils::Logger.warn("Workflow::QueryEnricher", "Enrichment failed, using original: #{e.message}")
        question
      end

      def self.known_table_names
        Glancer::Embedding
          .where(source_type: "schema")
          .pluck(:source_path)
          .filter_map do |path|
            fragment = path.to_s.split("#").last
            next if fragment.blank? || fragment == "foreign_keys" || fragment.include?("/")

            fragment
          end
          .uniq
      rescue StandardError
        []
      end

      def self.build_history_block(history)
        return "" if history.blank?

        lines = history.last(4).map do |msg|
          if msg.role == "assistant" && msg.code.present?
            "#{msg.role.upcase} [#{msg.code_type}: #{msg.code.strip.truncate(120)}]: #{msg.content.truncate(160)}"
          else
            "#{msg.role.upcase}: #{msg.content.truncate(200)}"
          end
        end.join("\n")
        "## Recent Conversation\n#{lines}\n\n"
      end
      private_class_method :build_history_block

      # Fetches schema embedding content for tables explicitly @mentioned in the question.
      # Provides the code generator with column names and types for accurate specification.
      def self.schema_context_for(question, table_names)
        at_mentioned = question.scan(/@([A-Za-z]\w*)/).flatten
        relevant = at_mentioned.select { |mention| table_names.any? { |tbl| tbl.casecmp?(mention) } }
        return "" if relevant.empty?

        rows = Glancer::Embedding
               .where(source_type: "schema")
               .where("source_path LIKE '%#%'")
               .pluck(:source_path, :content)

        matched = relevant.flat_map do |mention|
          rows.filter_map do |(path, content)|
            table = path.split("#").last
            content if table.casecmp?(mention)
          end
        end.first(3)

        return "" if matched.empty?

        "## Referenced Schema\n#{matched.join("\n\n")}\n\n"
      rescue StandardError
        ""
      end
      private_class_method :schema_context_for
    end
  end
end
