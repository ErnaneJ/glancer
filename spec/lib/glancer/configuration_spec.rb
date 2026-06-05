# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Configuration do
  subject(:config) { described_class.new }

  # ── Constants ─────────────────────────────────────────────────────────────────

  describe "constants" do
    it "defines ADAPTERS_SUPPORTED" do
      expect(described_class::ADAPTERS_SUPPORTED).to contain_exactly(:postgres, :mysql, :mysql2, :sqlite)
    end

    it "defines LLM_PROVIDERS" do
      expect(described_class::LLM_PROVIDERS).to contain_exactly(:gemini, :openai, :openrouter)
    end

    it "defines LOG_VERBOSITY_LEVELS" do
      expect(described_class::LOG_VERBOSITY_LEVELS).to contain_exactly(:silent, :none, :info, :debug)
    end

    it "defines EMBEDDING_DEFAULTS for each LLM provider" do
      expect(described_class::EMBEDDING_DEFAULTS.keys).to contain_exactly(:gemini, :openai, :openrouter)
    end

    it "defines QUERY_MODES" do
      expect(described_class::QUERY_MODES).to contain_exactly(:sql, :activerecord)
    end
  end

  # ── Default values ────────────────────────────────────────────────────────────

  describe "default values" do
    it "sets llm_provider to :gemini" do
      expect(config.llm_provider).to eq(:gemini)
    end

    it "sets llm_model to gemini-2.0-flash" do
      expect(config.llm_model).to eq("gemini-2.0-flash")
    end

    it "sets schema_permission to false" do
      expect(config.schema_permission).to be(false)
    end

    it "sets models_permission to false" do
      expect(config.models_permission).to be(false)
    end

    it "sets log_verbosity to :info" do
      expect(config.log_verbosity).to eq(:info)
    end

    it "sets k to 5" do
      expect(config.k).to eq(5)
    end

    it "sets min_score to 0.6" do
      expect(config.min_score).to eq(0.6)
    end

    it "sets schema_documents_weight to 1.3" do
      expect(config.schema_documents_weight).to eq(1.3)
    end

    it "sets context_documents_weight to 1.2" do
      expect(config.context_documents_weight).to eq(1.2)
    end

    it "sets models_documents_weight to 1.1" do
      expect(config.models_documents_weight).to eq(1.1)
    end

    it "sets chunk_size to 1000" do
      expect(config.chunk_size).to eq(1000)
    end

    it "sets chunk_overlap to 150" do
      expect(config.chunk_overlap).to eq(150)
    end

    it "sets history_limit to 6" do
      expect(config.history_limit).to eq(6)
    end

    it "sets embedding_provider to nil" do
      expect(config.embedding_provider).to be_nil
    end

    it "sets embedding_model to nil" do
      expect(config.embedding_model).to be_nil
    end

    it "sets code_provider to nil" do
      expect(config.code_provider).to be_nil
    end

    it "sets code_model to nil" do
      expect(config.code_model).to be_nil
    end

    it "sets chat_provider to nil" do
      expect(config.chat_provider).to be_nil
    end

    it "sets chat_model to nil" do
      expect(config.chat_model).to be_nil
    end

    it "sets blazer_path to nil" do
      expect(config.blazer_path).to be_nil
    end

    it "sets query_mode to :sql" do
      expect(config.query_mode).to eq(:sql)
    end

    it "sets context_file_path to a string" do
      expect(config.context_file_path).to be_a(String)
    end

    it "sets api_key to nil" do
      expect(config.api_key).to be_nil
    end

    it "sets gemini_api_key to nil" do
      expect(config.gemini_api_key).to be_nil
    end

    it "sets openai_api_key to nil" do
      expect(config.openai_api_key).to be_nil
    end

    it "sets openrouter_api_key to nil" do
      expect(config.openrouter_api_key).to be_nil
    end

    it "sets log_output_path to nil" do
      expect(config.log_output_path).to be_nil
    end

    it "sets read_only_db to nil" do
      expect(config.read_only_db).to be_nil
    end

    it "sets max_llm_retries to 3" do
      expect(config.max_llm_retries).to eq(3)
    end

    it "sets llm_retry_delay to 60" do
      expect(config.llm_retry_delay).to eq(60)
    end
  end

  # ── adapter= ─────────────────────────────────────────────────────────────────

  describe "#adapter=" do
    it "accepts :sqlite" do
      config.adapter = :sqlite
      expect(config.adapter).to eq(:sqlite)
    end

    it "accepts :postgres" do
      config.adapter = :postgres
      expect(config.adapter).to eq(:postgres)
    end

    it "accepts :mysql" do
      config.adapter = :mysql
      expect(config.adapter).to eq(:mysql)
    end

    it "accepts :mysql2" do
      config.adapter = :mysql2
      expect(config.adapter).to eq(:mysql2)
    end

    it "raises ArgumentError for an unsupported adapter" do
      expect { config.adapter = :oracle }.to raise_error(ArgumentError, /adapter must be/)
    end
  end

  # ── read_only_db= ─────────────────────────────────────────────────────────────

  describe "#read_only_db=" do
    it "accepts nil" do
      config.read_only_db = nil
      expect(config.read_only_db).to be_nil
    end

    it "accepts a connection URL string" do
      config.read_only_db = "sqlite3:///tmp/test.db"
      expect(config.read_only_db).to eq("sqlite3:///tmp/test.db")
    end

    it "accepts :read_only symbol" do
      config.read_only_db = :read_only
      expect(config.read_only_db).to eq(:read_only)
    end

    it "raises ArgumentError for an integer" do
      expect { config.read_only_db = 42 }.to raise_error(ArgumentError)
    end
  end

  # ── llm_provider= ────────────────────────────────────────────────────────────

  describe "#llm_provider=" do
    described_class::LLM_PROVIDERS.each do |provider|
      it "accepts #{provider}" do
        config.llm_provider = provider
        expect(config.llm_provider).to eq(provider)
      end
    end

    it "raises ArgumentError for an unsupported provider" do
      expect { config.llm_provider = :anthropic }.to raise_error(ArgumentError, /llm_provider must be/)
    end
  end

  # ── llm_model= ───────────────────────────────────────────────────────────────

  describe "#llm_model=" do
    it "accepts a String" do
      config.llm_model = "gpt-4o"
      expect(config.llm_model).to eq("gpt-4o")
    end

    it "raises ArgumentError for a non-String" do
      expect { config.llm_model = 123 }.to raise_error(ArgumentError, /llm_model must be a String/)
    end
  end

  # ── schema_permission= ───────────────────────────────────────────────────────

  describe "#schema_permission=" do
    it "accepts true" do
      config.schema_permission = true
      expect(config.schema_permission).to be(true)
    end

    it "accepts false" do
      config.schema_permission = false
      expect(config.schema_permission).to be(false)
    end

    it "raises ArgumentError for non-boolean" do
      expect { config.schema_permission = "yes" }.to raise_error(ArgumentError)
    end
  end

  # ── models_permission= ───────────────────────────────────────────────────────

  describe "#models_permission=" do
    it "accepts true and false" do
      config.models_permission = true
      expect(config.models_permission).to be(true)
      config.models_permission = false
      expect(config.models_permission).to be(false)
    end

    it "raises ArgumentError for non-boolean" do
      expect { config.models_permission = 1 }.to raise_error(ArgumentError)
    end
  end

  # ── workflow_cache_ttl= ──────────────────────────────────────────────────────

  describe "#workflow_cache_ttl=" do
    it "accepts a numeric" do
      config.workflow_cache_ttl = 300
      expect(config.workflow_cache_ttl).to eq(300)
    end

    it "raises ArgumentError for something that doesn't respond to to_i" do
      expect { config.workflow_cache_ttl = Object.new }.to raise_error(ArgumentError)
    end
  end

  # ── context_file_path= ───────────────────────────────────────────────────────

  describe "#context_file_path=" do
    it "accepts a String path" do
      config.context_file_path = "config/my.md"
      expect(config.context_file_path).to eq("config/my.md")
    end

    it "raises ArgumentError for a non-String" do
      expect { config.context_file_path = :symbol }.to raise_error(ArgumentError)
    end
  end

  # ── api_key= / gemini_api_key= / openai_api_key= / openrouter_api_key= ───────

  %i[api_key gemini_api_key openai_api_key openrouter_api_key].each do |attr|
    describe "##{attr}=" do
      it "accepts nil" do
        config.public_send(:"#{attr}=", nil)
        expect(config.public_send(attr)).to be_nil
      end

      it "accepts a String" do
        config.public_send(:"#{attr}=", "sk-abc123")
        expect(config.public_send(attr)).to eq("sk-abc123")
      end

      it "raises ArgumentError for a non-String / non-nil" do
        expect { config.public_send(:"#{attr}=", 42) }.to raise_error(ArgumentError)
      end
    end
  end

  # ── log_output_path= ─────────────────────────────────────────────────────────

  describe "#log_output_path=" do
    it "accepts nil" do
      config.log_output_path = nil
      expect(config.log_output_path).to be_nil
    end

    it "accepts a String path" do
      config.log_output_path = "/var/log/glancer.log"
      expect(config.log_output_path).to eq("/var/log/glancer.log")
    end

    it "raises ArgumentError for non-String / non-nil" do
      expect { config.log_output_path = true }.to raise_error(ArgumentError)
    end
  end

  # ── log_verbosity= ───────────────────────────────────────────────────────────

  describe "#log_verbosity=" do
    described_class::LOG_VERBOSITY_LEVELS.each do |level|
      it "accepts :#{level}" do
        config.log_verbosity = level
        expect(config.log_verbosity).to eq(level)
      end
    end

    it "raises ArgumentError for an invalid verbosity" do
      expect { config.log_verbosity = :verbose }.to raise_error(ArgumentError)
    end
  end

  # ── k= ───────────────────────────────────────────────────────────────────────

  describe "#k=" do
    it "accepts an integer >= 1" do
      config.k = 10
      expect(config.k).to eq(10)
    end

    it "accepts 1 (minimum)" do
      config.k = 1
      expect(config.k).to eq(1)
    end

    it "raises ArgumentError for 0" do
      expect { config.k = 0 }.to raise_error(ArgumentError, /k must be an integer/)
    end

    it "raises ArgumentError for a float" do
      expect { config.k = 2.5 }.to raise_error(ArgumentError)
    end
  end

  # ── min_score= ───────────────────────────────────────────────────────────────

  describe "#min_score=" do
    it "accepts 0.0" do
      config.min_score = 0.0
      expect(config.min_score).to eq(0.0)
    end

    it "accepts 1.0" do
      config.min_score = 1.0
      expect(config.min_score).to eq(1.0)
    end

    it "accepts a value in between" do
      config.min_score = 0.75
      expect(config.min_score).to eq(0.75)
    end

    it "raises ArgumentError above 1.0" do
      expect { config.min_score = 1.1 }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError below 0.0" do
      expect { config.min_score = -0.1 }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for a non-Numeric" do
      expect { config.min_score = "0.5" }.to raise_error(ArgumentError)
    end
  end

  # ── weight setters ────────────────────────────────────────────────────────────

  %i[schema_documents_weight context_documents_weight models_documents_weight].each do |attr|
    describe "##{attr}=" do
      it "accepts a numeric >= 1" do
        config.public_send(:"#{attr}=", 1.5)
        expect(config.public_send(attr)).to eq(1.5)
      end

      it "accepts exactly 1" do
        config.public_send(:"#{attr}=", 1)
        expect(config.public_send(attr)).to eq(1)
      end

      it "raises ArgumentError for a value below 1" do
        expect { config.public_send(:"#{attr}=", 0.9) }.to raise_error(ArgumentError)
      end

      it "raises ArgumentError for a non-Numeric" do
        expect { config.public_send(:"#{attr}=", "big") }.to raise_error(ArgumentError)
      end
    end
  end

  # ── chunk_size= ──────────────────────────────────────────────────────────────

  describe "#chunk_size=" do
    it "accepts 100 (minimum)" do
      config.chunk_size = 100
      expect(config.chunk_size).to eq(100)
    end

    it "raises ArgumentError for 99" do
      expect { config.chunk_size = 99 }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for a float" do
      expect { config.chunk_size = 200.5 }.to raise_error(ArgumentError)
    end
  end

  # ── chunk_overlap= ───────────────────────────────────────────────────────────

  describe "#chunk_overlap=" do
    it "accepts 0" do
      config.chunk_overlap = 0
      expect(config.chunk_overlap).to eq(0)
    end

    it "accepts positive integers" do
      config.chunk_overlap = 50
      expect(config.chunk_overlap).to eq(50)
    end

    it "raises ArgumentError for negative values" do
      expect { config.chunk_overlap = -1 }.to raise_error(ArgumentError)
    end
  end

  # ── history_limit= ───────────────────────────────────────────────────────────

  describe "#history_limit=" do
    it "accepts 1" do
      config.history_limit = 1
      expect(config.history_limit).to eq(1)
    end

    it "raises ArgumentError for 0" do
      expect { config.history_limit = 0 }.to raise_error(ArgumentError)
    end
  end

  # ── statement_timeout= ───────────────────────────────────────────────────────

  describe "#statement_timeout=" do
    it "accepts a numeric" do
      config.statement_timeout = 60
      expect(config.statement_timeout).to eq(60)
    end

    it "raises ArgumentError for an object that doesn't respond to to_i" do
      expect { config.statement_timeout = Object.new }.to raise_error(ArgumentError)
    end
  end

  # ── embedding_provider= ──────────────────────────────────────────────────────

  describe "#embedding_provider=" do
    it "accepts nil" do
      config.embedding_provider = nil
      expect(config.embedding_provider).to be_nil
    end

    described_class::LLM_PROVIDERS.each do |p|
      it "accepts :#{p}" do
        config.embedding_provider = p
        expect(config.embedding_provider).to eq(p)
      end
    end

    it "raises ArgumentError for an invalid provider" do
      expect { config.embedding_provider = :unknown }.to raise_error(ArgumentError)
    end
  end

  # ── embedding_model= ─────────────────────────────────────────────────────────

  describe "#embedding_model=" do
    it "accepts nil" do
      config.embedding_model = nil
      expect(config.embedding_model).to be_nil
    end

    it "accepts a String" do
      config.embedding_model = "text-embedding-3-small"
      expect(config.embedding_model).to eq("text-embedding-3-small")
    end

    it "raises ArgumentError for non-String / non-nil" do
      expect { config.embedding_model = 42 }.to raise_error(ArgumentError)
    end
  end

  # ── code_provider= / code_model= ───────────────────────────────────────────────

  describe "#code_provider=" do
    it "accepts nil" do
      config.code_provider = nil
      expect(config.code_provider).to be_nil
    end

    it "accepts a valid LLM provider" do
      config.code_provider = :openai
      expect(config.code_provider).to eq(:openai)
    end

    it "raises ArgumentError for invalid provider" do
      expect { config.code_provider = :bad }.to raise_error(ArgumentError)
    end
  end

  describe "#code_model=" do
    it "accepts nil" do
      config.code_model = nil
      expect(config.code_model).to be_nil
    end

    it "accepts a String" do
      config.code_model = "gpt-4o"
      expect(config.code_model).to eq("gpt-4o")
    end

    it "raises ArgumentError for non-String / non-nil" do
      expect { config.code_model = 1 }.to raise_error(ArgumentError)
    end
  end

  # ── chat_provider= / chat_model= ─────────────────────────────────────────────

  describe "#chat_provider=" do
    it "accepts nil" do
      config.chat_provider = nil
      expect(config.chat_provider).to be_nil
    end

    it "accepts a valid LLM provider" do
      config.chat_provider = :openrouter
      expect(config.chat_provider).to eq(:openrouter)
    end

    it "raises ArgumentError for invalid provider" do
      expect { config.chat_provider = :bad }.to raise_error(ArgumentError)
    end
  end

  describe "#chat_model=" do
    it "accepts nil and String" do
      config.chat_model = nil
      expect(config.chat_model).to be_nil
      config.chat_model = "claude-3"
      expect(config.chat_model).to eq("claude-3")
    end

    it "raises ArgumentError for non-String / non-nil" do
      expect { config.chat_model = true }.to raise_error(ArgumentError)
    end
  end

  # ── blazer_path= ─────────────────────────────────────────────────────────────

  describe "#blazer_path=" do
    it "accepts nil" do
      config.blazer_path = nil
      expect(config.blazer_path).to be_nil
    end

    it "accepts a String" do
      config.blazer_path = "/analytics"
      expect(config.blazer_path).to eq("/analytics")
    end

    it "raises ArgumentError for non-String / non-nil" do
      expect { config.blazer_path = :auto }.to raise_error(ArgumentError)
    end
  end

  # ── Resolved methods ──────────────────────────────────────────────────────────

  describe "#resolved_embedding_provider" do
    it "falls back to llm_provider when embedding_provider is nil" do
      config.embedding_provider = nil
      config.llm_provider       = :openai
      expect(config.resolved_embedding_provider).to eq(:openai)
    end

    it "returns embedding_provider when set" do
      config.llm_provider       = :gemini
      config.embedding_provider = :openai
      expect(config.resolved_embedding_provider).to eq(:openai)
    end
  end

  describe "#resolved_embedding_model" do
    it "returns the configured embedding_model when set" do
      config.embedding_model = "my-custom-model"
      expect(config.resolved_embedding_model).to eq("my-custom-model")
    end

    it "falls back to EMBEDDING_DEFAULTS for gemini" do
      config.embedding_model    = nil
      config.embedding_provider = :gemini
      expect(config.resolved_embedding_model).to eq(described_class::EMBEDDING_DEFAULTS[:gemini])
    end

    it "falls back to EMBEDDING_DEFAULTS for openai" do
      config.embedding_model    = nil
      config.embedding_provider = :openai
      expect(config.resolved_embedding_model).to eq(described_class::EMBEDDING_DEFAULTS[:openai])
    end
  end

  describe "#resolved_code_provider" do
    it "falls back to llm_provider when code_provider is nil" do
      config.code_provider = nil
      config.llm_provider = :openai
      expect(config.resolved_code_provider).to eq(:openai)
    end

    it "returns code_provider when set" do
      config.code_provider = :openrouter
      expect(config.resolved_code_provider).to eq(:openrouter)
    end
  end

  describe "#resolved_code_model" do
    it "falls back to llm_model when code_model is nil" do
      config.code_model = nil
      config.llm_model = "base-model"
      expect(config.resolved_code_model).to eq("base-model")
    end

    it "returns code_model when set" do
      config.code_model = "sql-specialist"
      expect(config.resolved_code_model).to eq("sql-specialist")
    end
  end

  describe "#resolved_chat_provider" do
    it "falls back to llm_provider when chat_provider is nil" do
      config.chat_provider = nil
      config.llm_provider  = :openai
      expect(config.resolved_chat_provider).to eq(:openai)
    end

    it "returns chat_provider when set" do
      config.chat_provider = :openrouter
      expect(config.resolved_chat_provider).to eq(:openrouter)
    end
  end

  describe "#resolved_chat_model" do
    it "falls back to llm_model when chat_model is nil" do
      config.chat_model = nil
      config.llm_model  = "base-model"
      expect(config.resolved_chat_model).to eq("base-model")
    end

    it "returns chat_model when set" do
      config.chat_model = "chat-specialist"
      expect(config.resolved_chat_model).to eq("chat-specialist")
    end
  end

  describe "#resolved_blazer_path" do
    it "returns nil when Blazer is not defined" do
      hide_const("Blazer::Engine") if defined?(Blazer::Engine)
      config.blazer_path = nil
      expect(config.resolved_blazer_path).to be_nil
    end

    it "returns explicitly set blazer_path over auto-detection" do
      config.blazer_path = "/my-blazer"
      expect(config.resolved_blazer_path).to eq("/my-blazer")
    end
  end

  describe "#resolved_adapter" do
    it "returns the configured adapter" do
      config.adapter = :sqlite
      expect(config.resolved_adapter).to eq(:sqlite)
    end

    it "normalises 'postgresql' string to :postgres" do
      allow(config).to receive(:adapter).and_return("postgresql")
      expect(config.resolved_adapter).to eq(:postgres)
    end
  end

  # ── Class methods ─────────────────────────────────────────────────────────────

  describe ".infer_adapter" do
    it "returns :sqlite when using the test SQLite connection" do
      adapter = described_class.infer_adapter
      expect(adapter).to eq(:sqlite)
    end

    it "returns nil when ActiveRecord raises" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError)
      expect(described_class.infer_adapter).to be_nil
    end
  end

  describe ".valid_table_name?" do
    it "returns true for a table that exists (glancer_chats)" do
      expect(described_class.valid_table_name?("glancer_chats")).to be(true)
    end

    it "returns false for a table that does not exist" do
      expect(described_class.valid_table_name?("nonexistent_table")).to be(false)
    end

    it "returns false when ActiveRecord raises" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError)
      expect(described_class.valid_table_name?("anything")).to be(false)
    end
  end

  # ── query_mode= ──────────────────────────────────────────────────────────────

  describe "#query_mode=" do
    it "accepts :sql" do
      config.query_mode = :sql
      expect(config.query_mode).to eq(:sql)
    end

    it "accepts :activerecord" do
      config.query_mode = :activerecord
      expect(config.query_mode).to eq(:activerecord)
    end

    it "raises ArgumentError for an invalid mode" do
      expect { config.query_mode = :graphql }
        .to raise_error(ArgumentError, /query_mode must be one of/)
    end

    it "raises ArgumentError for a String value" do
      expect { config.query_mode = "sql" }.to raise_error(ArgumentError)
    end
  end

  # ── query_enrichment_enabled= ─────────────────────────────────────────────

  describe "#query_enrichment_enabled=" do
    it "defaults to false" do
      expect(config.query_enrichment_enabled).to be(false)
    end

    it "accepts true" do
      config.query_enrichment_enabled = true
      expect(config.query_enrichment_enabled).to be(true)
    end

    it "accepts false" do
      config.query_enrichment_enabled = true
      config.query_enrichment_enabled = false
      expect(config.query_enrichment_enabled).to be(false)
    end

    it "raises ArgumentError for non-boolean values" do
      expect { config.query_enrichment_enabled = "yes" }.to raise_error(ArgumentError)
    end
  end

  # ── enrichment_provider= ──────────────────────────────────────────────────

  describe "#enrichment_provider=" do
    it "defaults to nil" do
      expect(config.enrichment_provider).to be_nil
    end

    it "accepts a valid provider" do
      config.enrichment_provider = :openai
      expect(config.enrichment_provider).to eq(:openai)
    end

    it "accepts nil" do
      config.enrichment_provider = :gemini
      config.enrichment_provider = nil
      expect(config.enrichment_provider).to be_nil
    end

    it "raises ArgumentError for invalid providers" do
      expect { config.enrichment_provider = :unknown }.to raise_error(ArgumentError)
    end
  end

  # ── enrichment_model= ─────────────────────────────────────────────────────

  describe "#enrichment_model=" do
    it "defaults to nil" do
      expect(config.enrichment_model).to be_nil
    end

    it "accepts a String model name" do
      config.enrichment_model = "gemini-2.0-flash"
      expect(config.enrichment_model).to eq("gemini-2.0-flash")
    end

    it "accepts nil" do
      config.enrichment_model = "some-model"
      config.enrichment_model = nil
      expect(config.enrichment_model).to be_nil
    end

    it "raises ArgumentError for non-string values" do
      expect { config.enrichment_model = :flash }.to raise_error(ArgumentError)
    end
  end

  # ── resolved_enrichment_provider / resolved_enrichment_model ──────────────

  describe "#resolved_enrichment_provider" do
    it "falls back to llm_provider when enrichment_provider is nil" do
      config.llm_provider = :openai
      config.enrichment_provider = nil
      expect(config.resolved_enrichment_provider).to eq(:openai)
    end

    it "returns enrichment_provider when set" do
      config.enrichment_provider = :openrouter
      expect(config.resolved_enrichment_provider).to eq(:openrouter)
    end
  end

  describe "#resolved_enrichment_model" do
    it "falls back to llm_model when enrichment_model is nil" do
      config.llm_model = "gpt-4o"
      config.enrichment_model = nil
      expect(config.resolved_enrichment_model).to eq("gpt-4o")
    end

    it "returns enrichment_model when set" do
      config.enrichment_model = "gemini-2.0-flash"
      expect(config.resolved_enrichment_model).to eq("gemini-2.0-flash")
    end
  end

  # ── max_llm_retries= ─────────────────────────────────────────────────────────

  describe "#max_llm_retries=" do
    it "defaults to 3" do
      expect(config.max_llm_retries).to eq(3)
    end

    it "accepts 0 (disables retries)" do
      config.max_llm_retries = 0
      expect(config.max_llm_retries).to eq(0)
    end

    it "accepts a positive integer" do
      config.max_llm_retries = 5
      expect(config.max_llm_retries).to eq(5)
    end

    it "raises ArgumentError for a negative integer" do
      expect { config.max_llm_retries = -1 }.to raise_error(ArgumentError, /non-negative integer/)
    end

    it "raises ArgumentError for a non-integer" do
      expect { config.max_llm_retries = 2.5 }.to raise_error(ArgumentError, /non-negative integer/)
    end
  end

  # ── llm_retry_delay= ─────────────────────────────────────────────────────────

  describe "#llm_retry_delay=" do
    it "defaults to 60" do
      expect(config.llm_retry_delay).to eq(60)
    end

    it "accepts a positive integer" do
      config.llm_retry_delay = 30
      expect(config.llm_retry_delay).to eq(30)
    end

    it "accepts a positive float" do
      config.llm_retry_delay = 0.5
      expect(config.llm_retry_delay).to eq(0.5)
    end

    it "raises ArgumentError for zero" do
      expect { config.llm_retry_delay = 0 }.to raise_error(ArgumentError, /positive number/)
    end

    it "raises ArgumentError for a negative number" do
      expect { config.llm_retry_delay = -5 }.to raise_error(ArgumentError, /positive number/)
    end
  end
end
