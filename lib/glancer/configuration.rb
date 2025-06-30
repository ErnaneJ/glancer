module Glancer
  class Configuration
    attr_accessor :read_only_db, :adapter,
                  :llm_provider, :llm_model, :log_output_path,
                  :schema_permission, :models_permission, :log_verbosity,
                  :context_file_path, :api_key, :workflow_cache_ttl

    def initialize
      @adapter = Glancer::Configuration.infer_adapter
      @read_only_db = nil
      @llm_provider = :gemini
      @llm_model = "gemini-2.0-flash"
      @schema_permission = false
      @models_permission = false
      @workflow_cache_ttl = 5.minutes
      @context_file_path =  "config/glancer/llm_context.glancer.md"
      @api_key = nil
      @log_output_path = nil
      @log_verbosity = :info
    end

    def self.infer_adapter
      ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    rescue StandardError
      nil
    end
  end
end
