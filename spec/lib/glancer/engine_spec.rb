# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Engine do
  # ── configure_provider_key ────────────────────────────────────────────────

  describe ".configure_provider_key" do
    let(:llm_config) { double("RubyLLM::Config") }

    context "gemini provider" do
      it "sets gemini_api_key from gemini_api_key config" do
        Glancer.configuration.gemini_api_key = "g-key"
        allow(llm_config).to receive(:gemini_api_key=)
        described_class.configure_provider_key(llm_config, Glancer.configuration, :gemini)
        expect(llm_config).to have_received(:gemini_api_key=).with("g-key")
      end

      it "falls back to api_key when gemini_api_key is nil" do
        Glancer.configuration.gemini_api_key = nil
        Glancer.configuration.api_key = "fallback-key"
        allow(llm_config).to receive(:gemini_api_key=)
        described_class.configure_provider_key(llm_config, Glancer.configuration, :gemini)
        expect(llm_config).to have_received(:gemini_api_key=).with("fallback-key")
      end

      it "raises Glancer::Error when no API key is available" do
        Glancer.configuration.gemini_api_key = nil
        Glancer.configuration.api_key = nil
        expect { described_class.configure_provider_key(llm_config, Glancer.configuration, :gemini) }
          .to raise_error(Glancer::Error, /Gemini API key/)
      end
    end

    context "openai provider" do
      it "sets openai_api_key" do
        Glancer.configuration.openai_api_key = "oai-key"
        allow(llm_config).to receive(:openai_api_key=)
        described_class.configure_provider_key(llm_config, Glancer.configuration, :openai)
        expect(llm_config).to have_received(:openai_api_key=).with("oai-key")
      end

      it "raises Glancer::Error when no API key is available" do
        Glancer.configuration.openai_api_key = nil
        Glancer.configuration.api_key = nil
        expect { described_class.configure_provider_key(llm_config, Glancer.configuration, :openai) }
          .to raise_error(Glancer::Error, /OpenAI API key/)
      end
    end

    context "openrouter provider" do
      it "sets openrouter_api_key" do
        Glancer.configuration.openrouter_api_key = "or-key"
        allow(llm_config).to receive(:openrouter_api_key=)
        described_class.configure_provider_key(llm_config, Glancer.configuration, :openrouter)
        expect(llm_config).to have_received(:openrouter_api_key=).with("or-key")
      end

      it "raises Glancer::Error when no API key is available" do
        Glancer.configuration.openrouter_api_key = nil
        Glancer.configuration.api_key = nil
        expect { described_class.configure_provider_key(llm_config, Glancer.configuration, :openrouter) }
          .to raise_error(Glancer::Error, /OpenRouter API key/)
      end
    end

    context "unsupported provider" do
      it "raises Glancer::Error" do
        expect { described_class.configure_provider_key(llm_config, Glancer.configuration, :unknown_llm) }
          .to raise_error(Glancer::Error, /Unsupported LLM provider/)
      end
    end
  end

  # ── Initializer registration ──────────────────────────────────────────────

  describe "registered initializers" do
    let(:initializer_names) { described_class.initializers.map { |i| i.name.to_s } }

    it "registers glancer.append_migrations" do
      expect(initializer_names).to include("glancer.append_migrations")
    end

    it "registers glancer.assets" do
      expect(initializer_names).to include("glancer.assets")
    end

    it "registers glancer.load_tasks" do
      expect(initializer_names).to include("glancer.load_tasks")
    end

    it "registers glancer.configure_ruby_llm" do
      expect(initializer_names).to include("glancer.configure_ruby_llm")
    end
  end

  # ── glancer.configure_ruby_llm initializer body ───────────────────────────

  describe "glancer.configure_ruby_llm initializer" do
    let(:ruby_llm_config) { double("RubyLLM::Config") }

    before do
      allow(ruby_llm_config).to receive(:gemini_api_key=)
      allow(ruby_llm_config).to receive(:default_embedding_model=)
      allow(ruby_llm_config).to receive(:default_embedding_model).and_return("text-embedding-004")
      allow(RubyLLM).to receive(:configure).and_yield(ruby_llm_config)
    end

    def run_llm_initializer
      init = Glancer::Engine.initializers.find { |i| i.name.to_s == "glancer.configure_ruby_llm" }
      init.run(nil)
    end

    it "calls RubyLLM.configure" do
      expect(RubyLLM).to receive(:configure).and_yield(ruby_llm_config)
      run_llm_initializer
    end

    it "sets gemini_api_key on the RubyLLM config" do
      run_llm_initializer
      expect(ruby_llm_config).to have_received(:gemini_api_key=).with("test-api-key")
    end

    it "sets default_embedding_model on the RubyLLM config" do
      run_llm_initializer
      expect(ruby_llm_config).to have_received(:default_embedding_model=)
    end

    it "raises Glancer::Error when configure_provider_key raises" do
      allow(RubyLLM).to receive(:configure).and_raise(StandardError, "LLM error")
      expect { run_llm_initializer }.to raise_error(Glancer::Error, /RubyLLM configuration failed/)
    end

    it "skips when Glancer.configuration is nil" do
      Glancer.configuration = nil
      expect(RubyLLM).not_to receive(:configure)
      expect { run_llm_initializer }.not_to raise_error
    ensure
      Glancer.configuration = Glancer::Configuration.new.tap do |c|
        c.adapter        = :sqlite
        c.llm_provider   = :gemini
        c.llm_model      = "test-model"
        c.gemini_api_key = "test-api-key"
        c.log_verbosity  = :none
      end
    end
  end

  # ── glancer.append_migrations initializer body ───────────────────────────

  describe "glancer.append_migrations initializer" do
    def run_migrations_initializer(app)
      init = Glancer::Engine.initializers.find { |i| i.name.to_s == "glancer.append_migrations" }
      init.bind(Glancer::Engine).run(app)
    end

    it "skips migration append when app root matches engine root" do
      app = double("app")
      allow(app).to receive(:root).and_return(Glancer::Engine.root)
      expect(app).not_to receive(:config)
      run_migrations_initializer(app)
    end

    it "appends migration paths when app root differs from engine root" do
      app = double("app")
      allow(app).to receive(:root).and_return(Pathname.new("/some/other/app"))
      migrate_paths = double("migrate_paths")
      allow(migrate_paths).to receive(:<<)
      app_paths = double("app_paths")
      allow(app_paths).to receive(:[]).with("db/migrate").and_return(migrate_paths)
      allow(app).to receive(:config).and_return(double("app_config", paths: app_paths))
      expect { run_migrations_initializer(app) }.not_to raise_error
    end
  end

  # ── glancer.assets initializer body ──────────────────────────────────────

  describe "glancer.assets initializer" do
    def run_assets_initializer(app)
      init = Glancer::Engine.initializers.find { |i| i.name.to_s == "glancer.assets" }
      init.bind(Glancer::Engine).run(app)
    end

    it "registers asset paths and precompile list without raising" do
      asset_paths = []
      precompile  = []
      assets = double("assets")
      allow(assets).to receive(:paths).and_return(asset_paths)
      allow(assets).to receive(:precompile).and_return(precompile)
      allow(assets).to receive(:precompile=)
      app = double("app", config: double("config", assets: assets))
      expect { run_assets_initializer(app) }.not_to raise_error
    end
  end

  # ── glancer.load_tasks initializer body ──────────────────────────────────

  describe "glancer.load_tasks initializer" do
    def run_load_tasks_initializer
      init = Glancer::Engine.initializers.find { |i| i.name.to_s == "glancer.load_tasks" }
      init.bind(Glancer::Engine).run(nil)
    end

    it "loads rake task files without raising" do
      allow(Dir).to receive(:[]).and_return([])
      expect { run_load_tasks_initializer }.not_to raise_error
    end
  end
end
