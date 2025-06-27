Glancer.configure do |config|
  config.adapter = nil # :postgres, :mysql, :sqlite – will autodetect if nil
  config.read_only_db = nil
  config.llm_provider = :gemini
  config.llm_model = "gemini-1.5-flash"
  config.schema_permission = true
  config.models_permission = true
  config.context_file_path = "config/glancer_context.md"
end
