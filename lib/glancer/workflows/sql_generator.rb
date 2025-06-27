# lib/glancer/workflows/sql_generator.rb
module Glancer
  module Workflows
    class SQLGenerator
      FORBIDDEN_KEYWORDS = %w[delete update insert drop truncate alter].freeze

      def initialize(question)
        @question = question
      end

      def call
        puts("[Glancer::SQLGenerator] Generating SQL for question: #{@question.inspect}")

        context_docs = Retriever.search(@question).map(&:content)
        prompt = build_prompt(@question, context_docs)

        llm = RubyLLM.chat(
          provider: Glancer.configuration.llm_provider,
          model: Glancer.configuration.llm_model
        )
        response = llm.ask(prompt)

        sql = extract_sql(response.content)

        raise Glancer::Error, "Query blocked due to forbidden keywords" unless safe_sql?(sql)

        sql
      end

      private

      def build_prompt(question, context_chunks)
        <<~PROMPT
          You are a Ruby on Rails assistant with access to the database schema.

          Your task is to generate the **simplest, safest and most correct SQL query possible** based solely on the schema and user question.

          Use the following rules:

          - Always generate only **SELECT** queries
          - Do not guess data; rely strictly on context
          - Use **column aliases (AS ...)** to improve readability
          - Keep the SQL syntactically correct and executable
          - Return only the SQL, nothing else
          - Respect the **language of the user's question**

          Context:
          #{context_chunks.join("\n\n")}

          Question: #{question}

          Output:
          SQL (only):
        PROMPT
      end

      def extract_sql(text)
        text[/```sql\s*(.*?)\s*```/m, 1] || text.strip
      end

      def safe_sql?(sql)
        downcased = sql.downcase
        FORBIDDEN_KEYWORDS.none? { |kw| downcased.include?(kw) }
      end
    end
  end
end
