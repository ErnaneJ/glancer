# frozen_string_literal: true

module Glancer
  class Engine < ::Rails::Engine
    isolate_namespace Glancer

    config.i18n.load_path += Dir[root.join("config/locales/*.yml").to_s]

    initializer "glancer.append_migrations" do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "glancer.assets" do |app|
      app.config.assets.paths << root.join("app/assets/javascripts")
      app.config.assets.precompile += %w[
        glancer/application.js
      ]

      app.config.assets.paths << root.join("app/assets/stylesheets")
      app.config.assets.precompile += %w[
        glancer/application.css
        glancer/code-blocks.css
        glancer/table.css
        glancer/list.css
        glancer/scrollbar.css
      ]
      app.config.assets.paths << root.join("app/assets/config")
      app.config.assets.paths << root.join("app/assets/images")
    end

    initializer "glancer.load_tasks" do
      Dir[File.join(__dir__, "../../tasks/**/*.rake")].each { |f| load f }
    end

    initializer "glancer.configure_ruby_llm" do
      next unless Glancer.configuration

      Glancer::Utils::Logger.info("Engine", "Configuring RubyLLM with Glancer settings...")

      RubyLLM.configure do |config|
        glancer_cfg = Glancer.configuration
        provider = glancer_cfg.llm_provider.to_sym
        embed_provider = glancer_cfg.resolved_embedding_provider.to_sym

        Glancer::Utils::Logger.debug("Engine", "LLM provider: #{provider}, embedding provider: #{embed_provider}")

        Glancer::Engine.configure_provider_key(config, glancer_cfg, provider)
        Glancer::Engine.configure_provider_key(config, glancer_cfg, embed_provider) if embed_provider != provider

        config.default_embedding_model = glancer_cfg.resolved_embedding_model

        Glancer::Utils::Logger.info("Engine",
                                    "RubyLLM configured — chat: #{provider}/#{glancer_cfg.llm_model}, " \
                                    "embeddings: #{embed_provider}/#{config.default_embedding_model}")
      end

      Glancer::Utils::Logger.info("Engine", "RubyLLM configuration completed.")
    rescue StandardError => e
      Glancer::Utils::Logger.error("Engine", "Failed to configure RubyLLM: #{e.class} - #{e.message}")
      Glancer::Utils::Logger.debug("Engine", "Backtrace:\n#{e.backtrace.join("\n")}")
      raise Glancer::Error, "RubyLLM configuration failed: #{e.message}"
    end

    def self.configure_provider_key(config, glancer_cfg, provider)
      case provider
      when :gemini
        key = glancer_cfg.gemini_api_key || glancer_cfg.api_key
        raise Glancer::Error, "Gemini API key is required but not configured." if key.nil? || key.empty?

        config.gemini_api_key = key
      when :openai
        key = glancer_cfg.openai_api_key || glancer_cfg.api_key
        raise Glancer::Error, "OpenAI API key is required but not configured." if key.nil? || key.empty?

        config.openai_api_key = key
      when :openrouter
        key = glancer_cfg.openrouter_api_key || glancer_cfg.api_key
        raise Glancer::Error, "OpenRouter API key is required but not configured." if key.nil? || key.empty?

        config.openrouter_api_key = key
      else
        raise Glancer::Error, "Unsupported LLM provider: #{provider.inspect}"
      end
    end
  end
end
