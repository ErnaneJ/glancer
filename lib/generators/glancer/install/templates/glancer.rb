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

  # Maximum time a single SQL query may run before being killed.
  # PostgreSQL uses SET statement_timeout; MySQL uses SET max_execution_time.
  # SQLite has no server-side timeout enforcement.
  config.statement_timeout = 30.seconds

  # ─────────────────────────────────────────────────────────────────────────────
  # LLM — Chat / SQL generation
  # ─────────────────────────────────────────────────────────────────────────────

  # Provider for chat completions (SQL generation and response humanization).
  # Accepted: :gemini | :openai | :openrouter
  config.llm_provider = :gemini

  # Model name for completions. Must be valid for the selected provider.
  #   Gemini:     "gemini-2.0-flash", "gemini-1.5-pro", ...
  #   OpenAI:     "gpt-4o", "gpt-4o-mini", ...
  #   OpenRouter: "anthropic/claude-3.5-sonnet", "openai/gpt-4o", ...
  config.llm_model = "gemini-2.0-flash"

  # ─────────────────────────────────────────────────────────────────────────────
  # LLM — Embeddings
  # ─────────────────────────────────────────────────────────────────────────────

  # Provider used exclusively for generating embeddings (indexing + retrieval).
  # Defaults to llm_provider when nil. Useful when using OpenRouter for chat
  # but a dedicated provider (Gemini/OpenAI) for embeddings, since OpenRouter
  # does not reliably expose embedding models.
  # Accepted: nil | :gemini | :openai | :openrouter
  config.embedding_provider = nil

  # Embedding model override. When nil, Glancer picks the best default for the
  # resolved embedding provider:
  #   Gemini:  "text-embedding-004"
  #   OpenAI:  "text-embedding-3-large"
  config.embedding_model = nil

  # ─────────────────────────────────────────────────────────────────────────────
  # API Keys
  # ─────────────────────────────────────────────────────────────────────────────

  # Use provider-specific keys (preferred) or api_key as a generic fallback.
  config.gemini_api_key     = ENV["GEMINI_API_KEY"]
  # config.openai_api_key    = ENV["OPENAI_API_KEY"]
  # config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  # config.api_key           = ENV["LLM_API_KEY"]  # generic fallback for any provider

  # ─── OpenRouter example ────────────────────────────────────────────────────
  # config.llm_provider       = :openrouter
  # config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
  # config.llm_model          = "anthropic/claude-3.5-sonnet"
  # config.embedding_provider = :gemini          # recommended: dedicated embed provider
  # config.gemini_api_key     = ENV["GEMINI_API_KEY"]
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
  config.schema_documents_weight  = 1.3  # db/schema.rb table definitions
  config.context_documents_weight = 1.2  # custom context Markdown file
  config.models_documents_weight  = 1.1  # ActiveRecord model files

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
  config.workflow_cache_ttl = 1.minute

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
end
