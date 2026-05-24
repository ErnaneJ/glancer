# frozen_string_literal: true

module Glancer
  module Workflow
    class LLM
      def self.humanized_response(question, _data, code, mode: :sql)
        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_chat_provider,
          model: Glancer.configuration.resolved_chat_model,
          assume_model_exists: true
        )

        code_label = mode == :activerecord ? "Ruby/ActiveRecord expression" : "SQL query"
        code_lang  = mode == :activerecord ? "ruby" : "sql"

        context = <<~PROMPT
          You are **Glancer**, a concise database assistant.

          CRITICAL RULES:
          - **Language Match**: Respond ONLY in the same language as the user's question.
          - **Never say the query "ran", "executed", or "returned"** — the code was GENERATED to answer the user's question.
            The actual results are displayed separately in the UI.
          - **What to explain**: Describe WHAT the code does logically and WHY it answers the question.
          - **Brevity**: 2–4 sentences maximum. No bullet points unless truly necessary.
          - **No code repeat**: The generated code is already shown; do not include it in your response.
          - **No hallucinations**: You have no knowledge of the actual result values. Do not describe or infer data values.
          - **Formatting**: Use Markdown and bold for key terms.

          #{code_label.upcase} GENERATED to answer the user's question:
          ```#{code_lang}
          #{code}
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
          1. Do NOT start with a greeting. Get straight to the point.
          2. Tell the user that the table(s) **#{missing}** could not be found in the indexed schema.
          3. Suggest they check the schema viewer at `/glancer/db-schema` to see all available tables.
          4. Keep it to 2 sentences. Respond in the exact same language as the user's question.
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

      def self.explain_error(question, error_message, code, mode: :sql)
        chat = RubyLLM.chat(
          provider: Glancer.configuration.resolved_chat_provider,
          model: Glancer.configuration.resolved_chat_model,
          assume_model_exists: true
        )

        code_label = mode == :activerecord ? "Ruby/ActiveRecord expression" : "SQL"

        prompt = <<~PROMPT
          You are **Glancer**. The user asked: "#{question}".
          We tried to generate a #{code_label} but failed after 3 attempts.
          Last error: "#{error_message}"
          Last code attempted: "#{code}"

          Your task:
          1. Do NOT start with a greeting or salutation (no "Hi", "Hello", "Olá", "Oi", etc.). Get straight to the point.
          2. Explain briefly what went wrong and why (e.g., "The column 'status' doesn't exist in the 'pages' table").
          3. Suggest how the user could rephrase or what alternative they can try.
          4. Keep it concise — 2–3 sentences max.
          5. Respond in the user's language.
        PROMPT

        chat.ask(prompt).content
      end
    end
  end
end
