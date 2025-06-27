module Glancer
  class Engine < ::Rails::Engine
    isolate_namespace Glancer

    initializer :append_migrations do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "glancer.configure_ruby_llm" do
      Glancer.configuration ||= Glancer::Configuration.new

      RubyLLM.configure do |config|
        case Glancer.configuration.llm_provider.to_sym
        when :gemini
          config.gemini_api_key = Glancer.configuration.api_key
          config.default_embedding_model = "text-embedding-004"
        when :openai
          config.openai_api_key = Glancer.configuration.api_key
          config.default_embedding_model = "text-embedding-3-large"
        else
          raise "Unsupported LLM provider: #{Glancer.configuration.llm_provider.inspect}"
        end
      end
    end
  end
end
