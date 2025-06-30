module Glancer
  class Engine < ::Rails::Engine
    isolate_namespace Glancer

    initializer "glancer.append_migrations" do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "glancer.load_tasks" do
      Dir[File.join(__dir__, "../../tasks/**/*.rake")].each { |f| load f }
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
          if config.gemini_api_key.nil? || config.gemini_api_key.empty?
            Glancer::Utils::Logger.warn("Engine", "Gemini API key is not set. Please configure it in Glancer settings.")
            raise Glancer::Error, "Gemini API key is required but not configured."
          end
          config.default_embedding_model = "text-embedding-004"
          Glancer::Utils::Logger.info("Engine", "Configured Gemini provider for RubyLLM.")
        when :openai
          config.openai_api_key = Glancer.configuration.api_key
          if config.openai_api_key.nil? || config.openai_api_key.empty?
            Glancer::Utils::Logger.warn("Engine", "OpenAI API key is not set. Please configure it in Glancer settings.")
            raise Glancer::Error, "OpenAI API key is required but not configured."
          end
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
