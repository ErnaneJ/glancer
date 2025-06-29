module Glancer
  module Workflow
    class Builder
      def self.build_sql(question, context_docs)
        prompt = Glancer::Workflow::PromptBuilder.call(question, context_docs)
        response = RubyLLM.chat(
          provider: Glancer.configuration.llm_provider,
          model: Glancer.configuration.llm_model
        ).ask(prompt)

        response.content
      end
    end
  end
end
