module Glancer
  class Runner
    def self.invoke(question)
      puts("[Glancer::Runner] Question received: #{question.inspect}")

      context_docs = Retriever.search(question, k: 5).map(&:content)

      prompt = build_prompt(question, context_docs)

      chat = RubyLLM.chat(provider: Glancer.configuration.llm_provider, model: Glancer.configuration.llm_model)
      response = chat.ask(prompt)

      response.content
    end

    def self.build_prompt(question, context_docs)
      <<~PROMPT
        Você é um assistente inteligente com acesso ao schema e lógica de negócio de um sistema Rails.
        Abaixo estão trechos do schema ou regras da aplicação (contexto):

        #{context_docs.map { |doc| "- #{doc}" }.join("\n\n")}

        Com base nesse contexto, responda à seguinte pergunta de forma precisa e, se possível, gere a SQL correspondente:

        Pergunta: "#{question}"
      PROMPT
    end
  end
end
