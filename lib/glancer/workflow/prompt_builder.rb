module Glancer
  module Workflow
    class PromptBuilder
      def self.call(question, context_chunks)
        <<~PROMPT
          You are a Ruby on Rails assistant with access to the application's database schema.

          Your task is to generate the most simple, correct and safe SQL query possible based only on the schema and user question.

          ✅ Rules:
          - Only generate **SELECT** statements
          - Never generate destructive queries (DELETE, UPDATE, etc)
          - Use **column aliases (AS ...)** to improve readability
          - The query must be valid and executable
          - Do **not** return explanations
          - Respect the language used in the user's question

          🧠 Context:
          #{context_chunks.join("\n\n")}

          ❓ Question:
          #{question}

          🧾 Output:
          SQL only:
        PROMPT
      end
    end
  end
end
