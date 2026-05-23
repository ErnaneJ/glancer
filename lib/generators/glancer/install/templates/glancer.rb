# frozen_string_literal: true

# Glancer configuration
# Full reference: https://github.com/ernanej/glancer

Glancer.configure do |config|
  # ─────────────────────────────────────────────────────────────────────────────
  # Database
  # ─────────────────────────────────────────────────────────────────────────────

  # Adapter used to execute queries. Auto-detected from ActiveRecord when nil.
  # Accepted: :postgres | :mysql | :mysql2 | :sqlite
  config.adapter = nil

  # Optional read-only replica URL. Queries run against this connection when set.
  # Accepts a full Rails database URL string or :read_only (uses current connection
  # in read-only mode).
  config.read_only_db = nil

  # Maximum time a single query may run before being killed.
  # PostgreSQL uses SET statement_timeout; MySQL uses SET max_execution_time.
  # SQLite has no server-side timeout enforcement.
  config.statement_timeout = 30.seconds

  # ─────────────────────────────────────────────────────────────────────────────
  # Query mode
  # ─────────────────────────────────────────────────────────────────────────────

  # Controls how Glancer generates and executes database queries.
  # :sql          — LLM generates a raw SELECT statement (default, most portable)
  # :activerecord — LLM generates a Ruby/ActiveRecord expression; lets the LLM
  #                 reuse your model scopes, associations, and named queries
  config.query_mode = :sql

  # ─────────────────────────────────────────────────────────────────────────────
  # LLM — Default provider (fallback for all roles below)
  # ─────────────────────────────────────────────────────────────────────────────

  # Default provider for all LLM calls. Used when role-specific providers are nil.
  # Accepted: :gemini | :openai | :openrouter
  config.llm_provider = :gemini

  # Default model. Used when role-specific models are nil.
  #   Gemini:     "gemini-2.0-flash", "gemini-1.5-pro", ...
  #   OpenAI:     "gpt-4o", "gpt-4o-mini", ...
  #   OpenRouter: "anthropic/claude-3.5-sonnet", "openai/gpt-4o", ...
  config.llm_model = "gemini-2.0-flash"

  # ─────────────────────────────────────────────────────────────────────────────
  # LLM — Code generation (overrides default for query building)
  # ─────────────────────────────────────────────────────────────────────────────

  # Provider used for code generation. Nil → falls back to llm_provider.
  # Useful when you want a code-focused model (e.g. gpt-4o) for query generation
  # and a cheaper model for responses.
  # Accepted: nil | :gemini | :openai | :openrouter
  config.code_provider = nil

  # Model used for code generation. Nil → falls back to llm_model.
  config.code_model = nil

  # ─────────────────────────────────────────────────────────────────────────────
  # LLM — Chat responses (overrides default for humanized answers)
  # ─────────────────────────────────────────────────────────────────────────────

  # Provider used for humanizing results and generating chat responses.
  # Nil → falls back to llm_provider.
  # Accepted: nil | :gemini | :openai | :openrouter
  config.chat_provider = nil

  # Model used for chat responses. Nil → falls back to llm_model.
  config.chat_model = nil

  # ─────────────────────────────────────────────────────────────────────────────
  # LLM — Embeddings
  # ─────────────────────────────────────────────────────────────────────────────

  # Provider used exclusively for generating embeddings (indexing + retrieval).
  # Defaults to llm_provider when nil.
  #
  # IMPORTANT — OpenRouter embedding support:
  #   OpenRouter does not expose a native embedding API. If you use OpenRouter
  #   for chat/code generation, set embedding_provider to :gemini or :openai to
  #   avoid errors. If you must use an OpenRouter embedding model anyway, set
  #   embedding_model explicitly (e.g., "openai/text-embedding-3-small") —
  #   Glancer will bypass the model registry check automatically.
  #
  # Accepted: nil | :gemini | :openai | :openrouter
  config.embedding_provider = nil

  # Embedding model override. When nil, Glancer uses the provider default:
  #   Gemini:     "text-embedding-004"
  #   OpenAI:     "text-embedding-3-large"
  #   OpenRouter: "openai/text-embedding-3-small"  (must be passed as model ID)
  config.embedding_model = nil

  # ─────────────────────────────────────────────────────────────────────────────
  # API Keys
  # ─────────────────────────────────────────────────────────────────────────────

  # Use provider-specific keys (preferred) or api_key as a generic fallback.
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)
  # config.openai_api_key     = ENV.fetch("OPENAI_API_KEY", nil)
  # config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY", nil)
  # config.api_key            = ENV.fetch("LLM_API_KEY", nil)  # generic fallback for any provider

  # ─── Example: different providers per role ──────────────────────────────────
  # config.llm_provider       = :gemini                              # default fallback
  # config.llm_model          = "gemini-2.0-flash"
  # config.code_provider       = :openai                              # code-focused model for queries
  # config.code_model          = "gpt-4o"
  # config.chat_provider      = :gemini                              # cheaper for chat
  # config.chat_model         = "gemini-2.0-flash"
  # config.embedding_provider = :gemini                              # dedicated embeddings
  # config.embedding_model    = "text-embedding-004"
  # config.gemini_api_key     = ENV.fetch("GEMINI_API_KEY", nil)
  # config.openai_api_key     = ENV.fetch("OPENAI_API_KEY", nil)
  # ─── Example: OpenRouter for chat/code gen, Gemini for embeddings (recommended) ──
  # OpenRouter does not expose a native embedding API, so always pair it with
  # a dedicated embedding provider (:gemini or :openai).
  # config.llm_provider       = :openrouter
  # config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY", nil)
  # config.llm_model          = "anthropic/claude-3.5-sonnet"
  # config.code_model          = "deepseek/deepseek-r1:free"
  # config.embedding_provider = :gemini
  # config.gemini_api_key     = ENV.fetch("GEMINI_API_KEY", nil)
  # config.embedding_model    = "text-embedding-004"
  # ───────────────────────────────────────────────────────────────────────────

  # ─────────────────────────────────────────────────────────────────────────────
  # Indexing permissions
  # ─────────────────────────────────────────────────────────────────────────────

  # Allow Glancer to index db/schema.rb (table and column definitions).
  config.schema_permission = true

  # Allow Glancer to index app/models/**/*.rb (associations, validations, scopes).
  config.models_permission = false

  # Path to a Markdown file with domain context: business rules, table aliases,
  # common query patterns, etc. Add "--glancer-ignore" as the first line to skip.
  config.context_file_path = "config/glancer/llm_context.glancer.md"

  # ─────────────────────────────────────────────────────────────────────────────
  # Chunking (controls how documents are split before embedding)
  # ─────────────────────────────────────────────────────────────────────────────

  # Maximum characters per chunk. Smaller chunks are more precise; larger chunks
  # preserve more context. Default: 1000.
  config.chunk_size = 1000

  # Characters of overlap between consecutive chunks. Helps prevent context loss
  # at chunk boundaries. Default: 150 (~15% of chunk_size).
  config.chunk_overlap = 150

  # ─────────────────────────────────────────────────────────────────────────────
  # Retrieval
  # ─────────────────────────────────────────────────────────────────────────────

  # Number of top embedding chunks returned per query.
  config.k = 10

  # Minimum cosine similarity score [0.0–1.0] for a chunk to be included.
  # Lower values return more results but may include noise.
  config.min_score = 0.6

  # Relevance multipliers per document type (must be ≥ 1.0).
  # Higher weight = ranked higher in retrieved context.
  config.schema_documents_weight = 1.3 # db/schema.rb table definitions
  config.context_documents_weight = 1.2 # custom context Markdown file
  config.models_documents_weight = 1.1 # ActiveRecord model files

  # ─────────────────────────────────────────────────────────────────────────────
  # Conversation
  # ─────────────────────────────────────────────────────────────────────────────

  # Number of past messages included in the prompt for multi-turn context.
  config.history_limit = 6

  # ─────────────────────────────────────────────────────────────────────────────
  # Caching
  # ─────────────────────────────────────────────────────────────────────────────

  # How long identical questions are served from the in-memory cache without
  # calling the LLM again. Set to 0 to disable. Cache is process-local (not
  # shared across Puma workers or restarts).
  config.workflow_cache_ttl = 5.minutes

  # ─────────────────────────────────────────────────────────────────────────────
  # Logging
  # ─────────────────────────────────────────────────────────────────────────────

  # File path for Glancer logs. When nil, output goes to Rails.logger / STDOUT.
  config.log_output_path = nil # e.g. "log/glancer.log"

  # Log verbosity level.
  # :none  → silent
  # :info  → normal operational messages (default)
  # :debug → verbose, includes prompts and full backtraces
  config.log_verbosity = :info

  # ─────────────────────────────────────────────────────────────────────────────
  # Integrations
  # ─────────────────────────────────────────────────────────────────────────────

  # Blazer integration: enables an "Open in Blazer" button on generated queries.
  # Auto-detected if the blazer gem is installed (defaults to "/blazer").
  # Set explicitly to override the path, or to "" / nil to disable.
  # config.blazer_path = "/blazer"
end
