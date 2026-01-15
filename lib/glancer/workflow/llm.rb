module Glancer
  module Workflow
    class LLM
      def self.humanized_response(question, data, sql)
        chat = RubyLLM.chat(
          provider: Glancer.configuration.llm_provider,
          model: Glancer.configuration.llm_model
        )

        # Privacy layer: provide only a summary and a small sample to the LLM
        # data_sample = data.first(3)
        # data_summary = {
        #   total_rows: data.size,
        #   columns: data.first&.keys || [],
        #   sample: data_sample
        # }

        context = <<~PROMPT
          You are **Glancer**, a professional SQL assistant.

          CRITICAL RULES:
          - **Language Match**: You MUST detect the language of the user's question and respond ONLY in that language. If asked in Portuguese, respond in Portuguese.
          - **Metadata Focus**: Explain the query
          - **No Hallucinations**: You have no knowledge of the actual data rows. Do not assume values that are not in the provided metadata.
          - **Formatting**: Use Markdown, bold text for metrics, and lists for clarity.
          - Never show the SQL query because it is already provided below.

          SQL EXECUTED:
          ```sql
          #{sql}
          ```

          USER QUESTION:
          #{question}
        PROMPT

        chat.with_instructions(context)
        response = chat.ask(question)

        response.content
      rescue StandardError => e
        Glancer::Utils::Logger.error("Workflow::LLM", "Humanized response failed: #{e.message}")
        "I processed the query but failed to generate a humanized explanation. You can still see the raw data below."
      end

      def self.explain_error(question, error_message, sql)
        chat = RubyLLM.chat(provider: Glancer.configuration.llm_provider, model: Glancer.configuration.llm_model)

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
