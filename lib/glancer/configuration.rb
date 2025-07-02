module Glancer
  class Configuration
    ADAPTERS_SUPPORTED = %i[postgres mysql mysql2 sqlite].freeze
    LLM_PROVIDERS = %i[gemini openai].freeze
    LOG_VERBOSITY_LEVELS = %i[none info debug].freeze

    def initialize
      self.adapter = Glancer::Configuration.infer_adapter
      self.read_only_db = nil
      self.llm_provider = :gemini
      self.llm_model = "gemini-2.0-flash"
      self.schema_permission = false
      self.models_permission = false
      self.workflow_cache_ttl = 5.minutes
      self.context_file_path = "config/glancer/llm_context.glancer.md"
      self.api_key = nil
      self.log_output_path = nil
      self.log_verbosity = :info
      self.k = 5
      self.min_score = 0.6
      self.schema_documents_weight = 1.3
      self.context_documents_weight = 1.2
      self.models_documents_weight = 1.1
    end

    # === READERS ===
    attr_reader :adapter, :read_only_db, :llm_provider, :llm_model,
                :schema_permission, :models_permission, :workflow_cache_ttl,
                :context_file_path, :api_key, :log_output_path, :log_verbosity,
                :k, :min_score,
                :schema_documents_weight, :context_documents_weight, :models_documents_weight

    # === WRITERS ===
    def adapter=(value)
      unless ADAPTERS_SUPPORTED.include?(value)
        raise ArgumentError, "adapter must be #{
          ADAPTERS_SUPPORTED.join(", ")
        }"
      end

      @adapter = value
    end

    def read_only_db=(value)
      unless value.nil? || value.is_a?(String) || value == :read_only
        raise ArgumentError, "read_only_db must be nil, a connection URL string, or :read_only"
      end

      @read_only_db = value
    end

    def llm_provider=(value)
      unless LLM_PROVIDERS.include?(value)
        raise ArgumentError, "llm_provider must be #{
          LLM_PROVIDERS.join(", ")
        }"
      end

      @llm_provider = value
    end

    def llm_model=(value)
      raise ArgumentError, "llm_model must be a String" unless value.is_a?(String)

      @llm_model = value
    end

    def schema_permission=(value)
      raise ArgumentError, "schema_permission must be true or false" unless [true, false].include?(value)

      @schema_permission = value
    end

    def models_permission=(value)
      raise ArgumentError, "models_permission must be true or false" unless [true, false].include?(value)

      @models_permission = value
    end

    def workflow_cache_ttl=(value)
      raise ArgumentError, "workflow_cache_ttl must respond to to_i" unless value.respond_to?(:to_i)

      @workflow_cache_ttl = value
    end

    def context_file_path=(value)
      raise ArgumentError, "context_file_path must be a String" unless value.is_a?(String)

      @context_file_path = value
    end

    def api_key=(value)
      raise ArgumentError, "api_key must be nil or a String" unless value.nil? || value.is_a?(String)

      @api_key = value
    end

    def log_output_path=(value)
      raise ArgumentError, "log_output_path must be nil or a String" unless value.nil? || value.is_a?(String)

      @log_output_path = value
    end

    def log_verbosity=(value)
      raise ArgumentError, "log_verbosity must be :none, :info, or :debug" unless LOG_VERBOSITY_LEVELS.include?(value)

      @log_verbosity = value
    end

    def k=(value)
      raise ArgumentError, "k must be an integer ≥ 1" unless value.is_a?(Integer) && value >= 1

      @k = value
    end

    def min_score=(value)
      unless value.is_a?(Numeric) && value.between?(
        0.0, 1.0
      )
        raise ArgumentError,
              "min_score must be a number between 0.0 and 1.0"
      end

      @min_score = value
    end

    def schema_documents_weight=(value)
      unless value.is_a?(Numeric) && value >= 1
        raise ArgumentError,
              "schema_documents_weight must be a positive number greater than or equal to 1"
      end

      @schema_documents_weight = value
    end

    def context_documents_weight=(value)
      unless value.is_a?(Numeric) && value >= 1
        raise ArgumentError,
              "context_documents_weight must be a positive number greater than or equal to 1"
      end

      @context_documents_weight = value
    end

    def models_documents_weight=(value)
      unless value.is_a?(Numeric) && value >= 1
        raise ArgumentError,
              "models_documents_weight must be a positive number greater than or equal to 1"
      end

      @models_documents_weight = value
    end

    # === Auxiliary methods ===

    def self.infer_adapter
      ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    rescue StandardError
      nil
    end

    def self.valid_table_name?(table_name)
      ActiveRecord::Base.connection.tables.include?(table_name.to_s)
    rescue StandardError
      false
    end
  end
end
