module Glancer
  class Configuration
    attr_accessor :adapter, :read_only_db,
                  :llm_provider, :llm_model,
                  :schema_permission, :models_permission,
                  :context_file_path, :api_key, :workflow_cache_ttl

    def initialize
      @adapter = nil
      @read_only_db = nil
      @llm_provider = :gemini
      @llm_model = "gemini-1.5-flash"
      @schema_permission = false
      @models_permission = false
      @workflow_cache_ttl = 5.minutes
      @context_file_path = nil # "config/llm_context.glancer.md"
      @api_key = ENV["GEMINI_API_KEY"] # padrão via env
    end
  end
end
