module Glancer
  class Configuration
    attr_accessor :adapter, :read_only_db,
                  :llm_provider, :llm_model,
                  :schema_permission, :models_permission,
                  :context_file_path

    def initialize
      @adapter = nil
      @read_only_db = nil
      @llm_provider = :gemini
      @llm_model = "gemini-2.0-flash"
      @schema_permission = true
      @models_permission = true
      @context_file_path = "config/glancer_context.md"
    end
  end
end
