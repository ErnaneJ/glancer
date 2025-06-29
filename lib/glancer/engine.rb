module Glancer
  class Engine < ::Rails::Engine
    isolate_namespace Glancer

    initializer :append_migrations do |app|
      Glancer::Utils::Logger.info("Engine", "Appending Glancer migrations to host application...")

      if app.root.to_s.match?(root.to_s)
        Glancer::Utils::Logger.debug("Engine",
                                     "Engine and application share the same root. Skipping migration path append.")
      else
        config.paths["db/migrate"].expanded.each do |expanded_path|
          Glancer::Utils::Logger.debug("Engine", "Adding migration path: #{expanded_path}")
          app.config.paths["db/migrate"] << expanded_path
        end
      end

      Glancer::Utils::Logger.info("Engine", "Migration paths appended successfully.")
    end

    initializer "glancer.configure_ruby_llm" do
      Glancer::Utils::Logger.info("Engine", "Configuring RubyLLM with Glancer settings...")

      Glancer.configuration ||= Glancer::Configuration.new

      RubyLLM.configure do |config|
        provider = Glancer.configuration.llm_provider.to_sym
        Glancer::Utils::Logger.debug("Engine", "Selected LLM provider: #{provider}")

        case provider
        when :gemini
          config.gemini_api_key = Glancer.configuration.api_key
          config.default_embedding_model = "text-embedding-004"
          Glancer::Utils::Logger.info("Engine", "Configured Gemini provider for RubyLLM.")
        when :openai
          config.openai_api_key = Glancer.configuration.api_key
          config.default_embedding_model = "text-embedding-3-large"
          Glancer::Utils::Logger.info("Engine", "Configured OpenAI provider for RubyLLM.")
        else
          Glancer::Utils::Logger.error("Engine", "Unsupported LLM provider: #{provider.inspect}")
          raise Glancer::Error, "Unsupported LLM provider: #{provider.inspect}"
        end
      end

      Glancer::Utils::Logger.info("Engine", "RubyLLM configuration completed.")
    rescue StandardError => e
      Glancer::Utils::Logger.error("Engine", "Failed to configure RubyLLM: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Engine", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error.new("RubyLLM configuration failed: #{e.message}"), cause: e
    end
  end
end
