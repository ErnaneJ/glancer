# frozen_string_literal: true
module Glancer
  module Workflow
    class LLM
      def self.humanized_response(question, _data, sql)
        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_chat_provider,
          model: Glancer.configuration.resolved_chat_model,
          assume_model_exists: true
        )

        # Privacy layer: provide only a summary and a small sample to the LLM
        # data_sample = data.first(3)
        # data_summary = {
        #   total_rows: data.size,
        #   columns: data.first&.keys || [],
        #   sample: data_sample
        # }

        context = <<~PROMPT
          You are **Glancer**, a concise SQL assistant.

          CRITICAL RULES:
          - **Language Match**: Respond ONLY in the same language as the user's question.
          - **Never say the query "ran", "executed", or "returned"** — the query was GENERATED to answer the user's question. The actual results are displayed separately in the UI.
          - **What to explain**: Describe WHAT the query does logically (e.g., "it joins orders with customers to count purchases per month") and WHY it answers the question.
          - **Brevity**: 2–4 sentences maximum. No bullet points unless truly necessary.
          - **No SQL repeat**: The SQL is already shown; do not include it in your response.
          - **No hallucinations**: You have no knowledge of the actual result values. Do not describe or infer data values.
          - **Formatting**: Use Markdown and bold for key terms.

          SQL GENERATED to answer the user's question:
          ```sql
          #{sql}
          ```

          USER QUESTION:
          #{question}
        PROMPT

        custom = Glancer::Setting.get("custom_instructions")
        context += "\n\nADDITIONAL INSTRUCTIONS:\n#{custom}" if custom.present?

        chat.with_instructions(context)
        response = chat.ask(question)

        response.content
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::LLM", "Humanized response failed: #{e.message}")
        "I processed the query but failed to generate a humanized explanation. You can still see the raw data below."
      end

      def self.explain_missing_tables(question, error_message)
        missing = error_message.scan(/Missing table\(s\) in indexed schema: (.+)/).flatten.first ||
                  error_message.scan(/Table validation failed: Missing table\(s\) in indexed schema: (.+)/).flatten.first ||
                  "desconhecidas"

        prompt = <<~PROMPT
          You are **Glancer**, a helpful SQL assistant.

          The user asked: "#{question}"

          When I tried to generate the SQL query, I referenced table(s) that don't exist in the indexed schema: **#{missing}**.
          This is likely a naming mismatch (e.g., the user said "afiliados" but the actual table is "filiais").

          Please:
          1. Tell the user in a friendly way that the table(s) **#{missing}** could not be found in the database schema.
          2. Suggest they check the schema viewer at `/glancer/db-schema` to see all available tables.
          3. Ask them to rephrase the question using the correct table name.
          4. Keep it to 2-3 sentences. Respond in the exact same language as the user's question.
        PROMPT

        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_chat_provider,
          model: Glancer.configuration.resolved_chat_model,
          assume_model_exists: true
        )
        chat.ask(prompt).content
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::LLM", "explain_missing_tables failed: #{e.message}")
        "Não consegui encontrar a(s) tabela(s) **#{missing}** no schema indexado. " \
          "Acesse `/glancer/db-schema` para ver todas as tabelas disponíveis e reformule sua pergunta com o nome correto."
      end

      def self.generate_title(question)
        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_chat_provider,
          model: Glancer.configuration.resolved_chat_model,
          assume_model_exists: true
        )
        prompt = "Generate a concise, descriptive title (max 45 characters, no quotes, no punctuation at end) " \
                 "for a database query session starting with this question: #{question}"
        chat.ask(prompt).content.strip.truncate(50)
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::LLM", "generate_title failed: #{e.message}")
        question.truncate(45)
      end

      def self.explain_error(question, error_message, sql)
        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_chat_provider,
          model: Glancer.configuration.resolved_chat_model,
          assume_model_exists: true
        )

        prompt = <<~PROMPT
          You are **Glancer**. The user asked: "#{question}".
          We tried to generate SQL but failed after 3 attempts.
          Last error: "#{error_message}"
          Last SQL attempted: "#{sql}"

          Your task:
          1. Explain to the user in a friendly way that you couldn't process the request.
          2. Point out what might be wrong (e.g., "I couldn't find a connection between Table A and B").
          3. Suggest how the user could rephrase the question to be clearer.
          4. Respond in the user's language.
        PROMPT

        chat.ask(prompt).content
      end
    end
  end
end
