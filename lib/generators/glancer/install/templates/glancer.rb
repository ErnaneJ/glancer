# Glancer configuration initializer
#
# This file allows you to customize how Glancer behaves in your Rails application.
# You can control database access, LLM behavior, context indexing, logging, and more.

Glancer.configure do |config|
  # --------------------------------------
  # Database Adapter
  # --------------------------------------
  # Force a specific database adapter if needed.
  # Possible values: :postgres, :mysql, :sqlite
  # If set to nil, Glancer will attempt to autodetect from ActiveRecord.
  # config.adapter = nil

  # --------------------------------------
  # Read-only database URL (optional)
  # --------------------------------------
  # If you want Glancer to execute queries against a read-only replica,
  # provide the full Rails-compatible database URL here.
  # If nil, the primary connection is used.
  # config.read_only_db = nil

  # --------------------------------------
  # LLM Provider and Model
  # --------------------------------------
  # Select which provider to use for generating responses.
  # Supported: :gemini (default), :openai, :ollama
  # config.llm_provider = :gemini # default

  # Name of the model to be used for completions (provider-specific).
  # Examples:
  # - Gemini: "gemini-2.0-flash"
  # - OpenAI: "gpt-4-turbo"
  # config.llm_model = "gemini-2.0-flash"

  # --------------------------------------
  # Permissions
  # --------------------------------------
  # Whether the LLM is allowed to use the application's schema to reason.
  config.schema_permission = true

  # Whether the LLM is allowed to analyze ActiveRecord models for structure and logic.
  # config.models_permission = true

  # --------------------------------------
  # Prompt Context File
  # --------------------------------------
  # Optional Markdown/text file containing additional domain knowledge,
  # rules or business logic to be embedded and indexed.
  # Set to the relative path of your context file.
  # By default the file is created (config/llm_context.glancer.md) but 
  # If the file contains the line '--glancer-ignore' as the first line,
  # it will be skipped from indexing.
  config.context_file_path = "config/glancer/llm_context.glancer.md"

  # --------------------------------------
  # Caching
  # --------------------------------------
  # Time-to-live for cached workflow results (in seconds).
  # Helps avoid repeated LLM calls for identical questions.
  # config.workflow_cache_ttl = 5.minutes

  # --------------------------------------
  # API Key for LLM provider (optional)
  # --------------------------------------
  # If your selected provider requires an API key, you can set it here.
  # It's common to fetch this from environment variables.
  config.api_key = ENV["GEMINI_API_KEY"]

  # --------------------------------------
  # Logging
  # --------------------------------------
  # Optional path to write logs to a separate file.
  # If nil, logs go to Rails.logger (if available), or STDOUT otherwise.
  # config.log_output_path = nil

  # Level of verbosity for Glancer logs:
  # - :none   → disables logging
  # - :info   → normal logging (default)
  # - :debug  → verbose logging, useful for troubleshooting
  # config.log_verbosity = :info
end
