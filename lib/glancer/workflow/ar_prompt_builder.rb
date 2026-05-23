# frozen_string_literal: true

module Glancer
  module Workflow
    class ARPromptBuilder
      def self.custom_instructions_block
        custom = Glancer::Setting.get("custom_instructions")
        custom.present? ? "CUSTOM RULES — MUST BE FOLLOWED STRICTLY:\n#{custom}\n" : ""
      rescue StandardError
        ""
      end

      def self.call(question, embeddings, history: [])
        Glancer::Utils::Logger.info("Workflow::ARPromptBuilder", "Building AR prompt for: #{question.inspect}")

        now = Time.current.strftime("%Y-%m-%d %H:%M:%S")

        history_context = history.map do |msg|
          if msg.role == "assistant" && msg.code.present?
            "ASSISTANT (Ruby expression used): #{msg.code.strip}\nASSISTANT (response): #{msg.content}"
          else
            "#{msg.role.upcase}: #{msg.content}"
          end
        end.join("\n\n")

        schema_context = embeddings.map { |e| e.content.strip }.join("\n\n")

        <<~PROMPT
          Current datetime: #{now}

          You are a Ruby on Rails ActiveRecord expert.
          Your ONLY task is to generate a Ruby expression that reads data from the database using ActiveRecord.

          STRICT GUIDELINES:
          1. **Output**: Return ONLY the Ruby expression, optionally inside a ```ruby code block. No prose.
          2. **Read-only**: Only use read methods: .where, .joins, .includes, .select, .count, .sum, .average,
             .minimum, .maximum, .group, .order, .limit, .offset, .pluck, .first, .last, .all, .find, .find_by,
             .having, .distinct, .reorder, .references, .eager_load, .preload.
          3. **Forbidden**: NEVER call .destroy, .destroy_all, .delete, .delete_all, .update, .update_all,
             .save, .save!, .create, .create!, .insert, .upsert, .touch, or any write method.
          4. **Model names**: Use EXACT class names as they appear in the DATABASE CONTEXT (e.g., User, Order).
          5. **Result**: The expression must return an ActiveRecord::Relation, Array, Hash, Numeric, or String.
          6. **Aliases**: When using .select with raw columns, use AS aliases for clarity.
          7. **Single expression**: Prefer a single-line expression. Multi-line is allowed if necessary.

          DATABASE CONTEXT:
          #{schema_context}

          CONVERSATION HISTORY:
          #{history_context.presence || "(no prior messages)"}

          #{custom_instructions_block}
          NEW QUESTION:
          #{question}

          OUTPUT RUBY EXPRESSION ONLY:
        PROMPT
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::ARPromptBuilder", "Failed: #{e.message}")
        raise Glancer::Error, "AR prompt construction failed: #{e.message}"
      end
    end
  end
end
