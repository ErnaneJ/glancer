Glancer.configure do |config|
  config.adapter = nil # :postgres, :mysql, :sqlite – will autodetect if nil
  config.read_only_db = nil
  config.llm_provider = :gemini
  config.llm_model = "gemini-1.5-flash"
  config.schema_permission = true
  config.models_permission = true
  config.workflow_cache_ttl = 5.minutes
  config.context_file_path = nil # "config/llm_context.glancer.md"
  config.api_key = ENV["GEMINI_API_KEY"]
  config.log_output_path = nil # Default is to log to Rails logger or STDOUT
  config.log_verbosity = :info # :none | :info | :debug
end
