# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Glancer is a **Ruby on Rails engine (gem)** that adds natural language database querying to any Rails app via RAG (Retrieval-Augmented Generation) and LLMs. It indexes the host app's schema, models, and custom context into a vector store, then answers user questions with generated and executed SQL, returning humanized responses through a chat UI.

## Commands

```bash
# Development
bundle exec rake spec rubocop    # Default CI: tests + linting (both must pass)
bundle exec rake spec            # RSpec only
bundle exec rake rubocop         # RuboCop only

# Rake tasks (run in host app after mounting)
rails glancer:index:all          # Rebuild all embeddings (prompts confirmation)
rails glancer:index:schema       # Index db/schema.rb only
rails glancer:index:models       # Index app/models only
rails glancer:index:context      # Index custom context Markdown file
rails glancer:version            # Print gem version
```

## Architecture

### RAG Query Pipeline

The core workflow runs in `lib/glancer/workflow.rb` and follows this sequence per user message:

```
1. Embed question → cosine similarity search over glancer_embeddings
   - Weights: schema 1.3x, context 1.2x, models 1.1x
   - Filters: min_score (default 0.6), top-k (default 5)

2. Build prompt (PromptBuilder) with retrieved chunks + last 6 messages
   - LLM receives adapter type for syntax-specific SQL generation
   - Language directive: respond in the same language as the question

3. LLM generates SELECT-only SQL
   - SQLExtractor: parses ```sql blocks from raw LLM output
   - SQLSanitizer: blocks DELETE/UPDATE/INSERT/DROP/TRUNCATE/ALTER/CREATE/REPLACE
   - SQLValidator: verifies referenced tables exist in indexed schema

4. Execute inside a transaction that always rolls back (read-only safety)
   - Injects /*glancer,run_id:UUID*/ comment for audit trail
   - Creates Glancer::Audit record
   - Auto-retry up to 3 times via LLM error correction

5. LLM humanizes results; response cached in-memory (TTL configurable)
```

### Database Tables

| Table | Purpose |
|-------|---------|
| `glancer_chats` | Conversation containers |
| `glancer_messages` | User/assistant turns; stores `sql`, `successful` flag, optional `user_message_id` FK linking reply to source |
| `glancer_embeddings` | Vector store: `content`, `embedding` (JSONB on PG / JSON elsewhere), `source_type`, `source_path` |
| `glancer_audits` | Immutable query log: `question`, `sql`, `adapter`, `run_id` (unique UUID) |

### Indexers (`lib/glancer/indexer/`)

- **SchemaIndexer**: Splits `db/schema.rb` into per-table chunks by `create_table` blocks
- **ModelIndexer**: Reads `app/models/**/*.rb`, chunks at 1000 chars
- **ContextIndexer**: Reads custom Markdown from `config_file_path`; skips files whose first line is `--glancer-ignore`

Embeddings are regenerated on each `glancer:index:*` call (full re-index, not incremental).

### Configuration (`lib/glancer/configuration.rb`)

Singleton via `Glancer.configure { |config| }`. All setters validate on assignment (raise `ArgumentError` on invalid). Key non-obvious settings:

```ruby
config.adapter          # Auto-detected from ActiveRecord if nil
config.read_only_db     # Optional replica URL; connection opened per transaction, reset after
config.k                # Number of top embeddings retrieved (default 10)
config.min_score        # Cosine similarity floor 0.0–1.0 (default 0.6)
config.workflow_cache_ttl  # In-memory result cache TTL (NOT shared across processes)
```

### Frontend (`app/assets/`)

Stimulus JS + Turbo Streams with Tailwind CSS (CDN, dark mode default). Controllers:
- **MessageController**: form submit, typewriter effect (12ms/char), CSV export (client-side DOM traversal), SQL re-run
- **ChatController**: chat CRUD, copy-to-clipboard

Both controllers respond to `.html` and `.turbo_stream` formats. CSV generation happens entirely in the browser by traversing the rendered `<table>` DOM — there is no backend CSV endpoint.

### Routes

```ruby
resources :chats, only: [:index, :show, :create, :destroy] do
  resources :messages, only: [:create]
end
get  "/messages/:id/info"       # Side-panel with SQL + sources
post "/messages/:id/run_sql"    # Re-execute saved SQL without regenerating
root to: "chats#index"
```

## Non-Obvious Constraints

- **Transactions always roll back** — even on successful reads. This is intentional for read-only safety; do not add `raise ActiveRecord::Rollback` — it's already unconditional.
- **SQL audit comment is mandatory** — every executed query has `/*glancer,run_id:UUID*/` injected by Executor; removing this breaks audit tracking.
- **In-memory cache is process-local** — `Glancer::Workflow::Cache` uses a class-level `@@store` hash. It will not invalidate across Puma workers or restarts.
- **Vector search is O(n) pure Ruby** — no pgvector or native DB indexing. Large embedding tables will degrade retrieval performance noticeably.
- **ModelIndexer hard-codes 1000-char chunk size** — there is no configuration option for this.
- **Prompt language detection is LLM-instructed, not programmatic** — the system prompt tells the LLM to match input language; no ICU/language detection library is used.
- **`user_message_id` is a self-referential FK on `glancer_messages`** — assistant messages point to the user message that triggered them; this is used for threading in the UI info panel.

## Gem Development Notes

The gemspec (`glancer.gemspec`) includes only `.rb`, `.erb`, `.md`, `.yml`, `.rake` files. Assets follow normal Rails engine conventions with `config.assets.precompile` declared in the engine initializer.

To test changes against a host Rails app, use a `Gemfile` path reference: `gem 'glancer', path: '../glancer'`.
