<p align="center">
  <img src="./.github/assets/glancer-banner.svg" alt="Glancer" width="100%">
</p>

<p align="center">
  <strong>Natural language database queries for your Rails app — powered by RAG and LLMs.</strong>
</p>

<p align="center">
  <a href="https://github.com/ErnaneJ/glancer/actions/workflows/ci.yml">
    <img src="https://github.com/ErnaneJ/glancer/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <a href="https://github.com/ErnaneJ/glancer">
    <img src="https://github.com/ErnaneJ/glancer/raw/refs/heads/badge-generator/.github/badges/coverage.svg" alt="Coverage">
  </a>
  <a href="https://rubygems.org/gems/glancer">
    <img src="https://badge.fury.io/rb/glancer.svg" alt="Gem Version">
  </a>
  <a href="LICENSE.txt">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
  </a>
  <a href="https://www.ruby-lang.org/en/">
    <img src="https://img.shields.io/badge/ruby-%3E%3D%203.3-CC342D" alt="Ruby >= 3.3">
  </a>
  <a href="https://rubyonrails.org/">
    <img src="https://img.shields.io/badge/rails-%3E%3D%207.0-CC0000" alt="Rails >= 7.0">
  </a>
</p>

---

Glancer is a **Ruby on Rails engine** that mounts a full chat interface inside your app and lets anyone on your team query the database in plain language, no SQL required. You ask a question, Glancer retrieves the relevant schema context, generates a query, validates and executes it safely, then returns the results with a human-readable explanation.

```
"How many orders were placed in the last 30 days, grouped by status?"
→ SELECT executed, results shown, answer written in plain language.
```

[![DEMO](./.github/assets/demo.gif)](./.github/assets/demo.mp4)

## Why Glancer?

Every Rails app accumulates tables and columns whose meaning lives in the heads of a few engineers. Product managers open tickets for simple questions. Data teams copy-paste schemas into ChatGPT. Engineers write one-off queries for stakeholders.

Glancer removes that friction. It gives your app a persistent, context-aware database assistant that understands your domain,not just generic SQL, because it is taught your schema, your models, and your business rules through a plain Markdown file.

**Key design decisions:**

- **Safety first** — all queries run inside a transaction that always rolls back. No write statement can ever reach the database.
- **Your LLM, your cost** — bring your own Gemini, OpenAI, or OpenRouter key. Mix providers per role to balance cost and quality.
- **No external vector store** — embeddings live in your existing database. No Pinecone, no Weaviate, no extra infrastructure.
- **Rails-native** — mounted as an engine, uses Turbo and Stimulus, installs in under five minutes.
- **Dual query modes** — generate raw `SELECT` statements or Ruby ActiveRecord expressions depending on what fits your domain better.

## Requirements

| Dependency | Minimum version |
|---|---|
| Ruby | 3.3 |
| Rails | 7.0 |
| Database | SQLite, PostgreSQL, or MySQL / MariaDB |
| LLM provider | Gemini, OpenAI, or OpenRouter API key |

Glancer is built on top of [**ruby_llm**](https://github.com/crmne/ruby_llm), a provider-agnostic LLM client for Ruby. All LLM calls (query generation, humanized responses, embeddings, and optional question enrichment) go through ruby_llm, so any model it supports works with Glancer.

## Installation

### 1. Add to your Gemfile

```ruby
gem "glancer"
```

```bash
bundle install
```

### 2. Run the install generator

```bash
rails generate glancer:install
```

This creates:

- `config/initializers/glancer.rb` — your main configuration file
- `config/glancer/llm_context.glancer.md` — optional domain context written in Markdown
- Mounts the engine at `/glancer` in `config/routes.rb`

### 3. Migrate the database

```bash
rails db:migrate
```

### 4. Index your schema

```bash
rails glancer:index:all
```

### 5. Start asking questions

```
http://localhost:3000/glancer
```

## Configuration

Edit `config/initializers/glancer.rb`. Minimal working setup:

```ruby
Glancer.configure do |config|
  config.llm_provider   = :gemini
  config.llm_model      = "gemini-2.0-flash"
  config.gemini_api_key = ENV["GEMINI_API_KEY"]

  config.schema_permission = true  # allow indexing db/schema.rb
end
```

### Query mode

```ruby
config.query_mode = :sql          # (default) LLM generates a SELECT statement
config.query_mode = :activerecord # LLM generates a Ruby/ActiveRecord expression
```

ActiveRecord mode lets the LLM leverage model scopes, named associations, and Ruby idioms. SQL mode is more portable and works without any models loaded.

### Split providers per role

Different models can handle different responsibilities. This is the recommended setup for cost optimization:

```ruby
Glancer.configure do |config|
  config.llm_provider = :gemini               # fallback for any unspecified role

  # A capable model for accurate query generation
  config.code_provider = :openai
  config.code_model    = "gpt-4o"

  # A cheaper model for writing human-readable responses
  config.chat_provider = :gemini
  config.chat_model    = "gemini-2.0-flash"

  # Embedding model
  config.embedding_provider = :gemini
  config.embedding_model    = "text-embedding-004"

  # Optional: separate model to enrich ambiguous questions before retrieval
  config.query_enrichment_enabled = true
  config.enrichment_provider      = :gemini
  config.enrichment_model         = "gemini-2.0-flash"
end
```

### Read-only replica

Route all queries to a replica to offload your primary database:

```ruby
config.read_only_db = ENV["REPLICA_DATABASE_URL"]
```

### Full configuration reference

| Option | Default | Description |
|---|---|---|
| `adapter` | auto-detected | `:postgres`, `:mysql`, `:mysql2`, or `:sqlite` |
| `query_mode` | `:sql` | `:sql` (raw SELECT) or `:activerecord` (Ruby expression) |
| `read_only_db` | `nil` | Replica connection URL |
| `statement_timeout` | `30.seconds` | Max execution time; enforced server-side on PG and MySQL |
| `llm_provider` | `:gemini` | Default provider for all roles (`:gemini`, `:openai`, `:openrouter`) |
| `llm_model` | `"gemini-2.0-flash"` | Default model for all roles |
| `code_provider` / `code_model` | inherits default | Provider/model for query generation |
| `chat_provider` / `chat_model` | inherits default | Provider/model for humanized responses |
| `embedding_provider` / `embedding_model` | inherits default | Provider/model for embeddings |
| `enrichment_provider` / `enrichment_model` | inherits default | Provider/model for question enrichment |
| `query_enrichment_enabled` | `false` | Pre-retrieval question rewriting to inject table hints |
| `gemini_api_key` | `nil` | Gemini API key |
| `openai_api_key` | `nil` | OpenAI API key |
| `openrouter_api_key` | `nil` | OpenRouter API key |
| `schema_permission` | `false` | Index `db/schema.rb` |
| `models_permission` | `false` | Index `app/models/**/*.rb` |
| `context_file_path` | `"config/glancer/llm_context.glancer.md"` | Custom domain context file |
| `chunk_size` | `1000` | Max characters per embedding chunk |
| `chunk_overlap` | `150` | Overlap between consecutive chunks |
| `k` | `5` | Top-k chunks retrieved per question |
| `min_score` | `0.6` | Minimum cosine similarity score (0.0–1.0) |
| `schema_documents_weight` | `1.3` | Score boost for schema chunks |
| `context_documents_weight` | `1.2` | Score boost for context chunks |
| `models_documents_weight` | `1.1` | Score boost for model chunks |
| `history_limit` | `6` | Prior conversation turns included in the LLM prompt |
| `workflow_cache_ttl` | `5.minutes` | In-memory result cache TTL; `0` to disable |
| `log_verbosity` | `:info` | `:silent`, `:none`, `:info`, or `:debug` |
| `log_output_path` | `nil` | Log file path; `nil` writes to stdout |
| `blazer_path` | `nil` | Blazer base path; auto-detected when `blazer` gem is present |

## Indexing

Glancer embeds your schema, models, and custom context into the `glancer_embeddings` table. Re-run indexing whenever the schema changes significantly.

```bash
rails glancer:index:all       # Schema + models + context (prompts confirmation)
rails glancer:index:schema    # db/schema.rb only
rails glancer:index:models    # app/models/**/*.rb only
rails glancer:index:context   # Custom context Markdown file only
rails glancer:version         # Print the installed gem version
```

The schema indexer automatically enriches each table chunk with model association metadata (has_many, belongs_to, etc.) and generates a dedicated foreign key chunk, so the LLM understands relationships without you having to describe them manually.

### Custom context file

`config/glancer/llm_context.glancer.md` is where you document domain knowledge that lives outside the schema — enum values, business definitions, metric formulas, naming conventions:

```markdown
# Domain context

- `orders.status` values: "pending" | "paid" | "shipped" | "refunded".
- `users.role` can be "admin", "agent", or "customer". Admins are excluded from retention metrics.
- Monthly revenue = SUM(orders.total) WHERE status = "paid".
- When asked about "churn", use the `churned_at` column on the `subscriptions` table.
```

Add `--glancer-ignore` as the **first line** of the file to exclude it from indexing.

## Chat interface

Visit `/glancer` in your browser.

- **Async processing** — messages are handled in a background thread; the UI polls for completion so you can open a new chat while another query runs.
- **Step labels** — the interface shows what the pipeline is doing: enriching, retrieving context, generating code, validating, executing, preparing response.
- **@mention autocomplete** — type `@table_name` to pin a specific table to your question; it renders as a chip linked to the schema viewer.
- **Dual query modes** — generated SQL or Ruby is syntax-highlighted in the response.
- **Inline code editing** — modify the generated query and re-run it without asking a new question. Edited versions show a badge.
- **Results table** — with one-click CSV export (client-side, no backend endpoint).
- **Charts** — bar, line, doughnut, and scatter charts are auto-generated from the result set where meaningful.
- **Fullscreen charts** — expand any chart to a fullscreen dialog for detailed inspection.
- **Blazer integration** — open the SQL in Blazer pre-filled, if the gem is installed.
- **Audio input** — click the microphone to dictate your question.
- **Multi-language** — ask in any language; the LLM responds in the same language.
- **Custom instructions** — set persistent system instructions at `/glancer/settings`.
- **Schema viewer** — browse all indexed tables and columns at `/glancer/db-schema`.
- **Message details panel** — shows generated code, edit history, execution audit, sources used, and enriched question.

## Safety

Glancer is designed to be safe on production databases.

### SQL mode

| Layer | Mechanism |
|---|---|
| **No writes** | All queries run inside a transaction that unconditionally rolls back |
| **Keyword blocklist** | `DELETE`, `UPDATE`, `INSERT`, `DROP`, `TRUNCATE`, `ALTER`, `CREATE`, `REPLACE` are rejected before execution |
| **Table validation** | Referenced tables are checked against the indexed schema; unknown tables return a friendly error |
| **Statement timeout** | `statement_timeout` (PG) / `max_execution_time` (MySQL) kills runaway queries server-side |
| **Audit trail** | Every execution is recorded in `glancer_audits` with a unique `run_id` UUID |
| **Replica support** | Route queries to a read-only replica via `config.read_only_db` |

### ActiveRecord mode

| Layer | Mechanism |
|---|---|
| **No writes** | Same rolled-back transaction as SQL mode |
| **Method blocklist** | `.destroy`, `.delete`, `.update`, `.save`, `.create`, `.insert`, `.upsert`, `.touch` and variants are rejected |
| **Shell blocklist** | Backticks, `system()`, `exec()`, `spawn()` are rejected |
| **Eval blocklist** | `eval`, `instance_eval`, `class_eval` are rejected |
| **File write blocklist** | `FileUtils`, `File.write`, `IO.write` are rejected |
| **Dynamic load blocklist** | `require`, `load`, `autoload` are rejected |
| **Audit trail** | Same as SQL mode; `code_type: "activerecord"` recorded in `glancer_audits` |

## Internal database tables

| Table | Purpose |
|---|---|
| `glancer_chats` | Conversation containers |
| `glancer_messages` | User/assistant turns; stores generated code, code type, and processing status |
| `glancer_embeddings` | Vector store: content, embedding (JSONB on PG / JSON elsewhere), source type and path |
| `glancer_audits` | Immutable query log with unique `run_id` per execution |
| `glancer_code_versions` | Code edit history per message |
| `glancer_settings` | Runtime configuration (e.g. custom instructions) |

## Usage from Ruby

You can call Glancer's internals directly from the Rails console or your own code:

```ruby
# Re-index everything
Glancer::Indexer.rebuild_all!

# Run the full pipeline
result = Glancer::Workflow.run(chat.id, "Which products have never been ordered?")
# => { content: "...", code: "SELECT ...", code_type: "sql", successful: true, sources: [...] }

# Retrieve relevant chunks for a question (without running the full pipeline)
chunks = Glancer::Retriever.search("monthly revenue by region")

# Check SQL against the safety layer
Glancer::Workflow::SQLSanitizer.ensure_safe!("SELECT * FROM users")

# Check an ActiveRecord expression against the safety layer
Glancer::Workflow::ARSanitizer.ensure_safe!("User.where(active: true).count")

# Validate table references against the indexed schema
Glancer::Workflow::SQLValidator.validate_tables_exist!("SELECT * FROM orders JOIN unknown_table")
```

## Development

```bash
git clone https://github.com/ErnaneJ/glancer
cd glancer
bundle install
```

```bash
bundle exec rake          # Tests + RuboCop (mirrors CI)
bundle exec rake spec     # RSpec only
bundle exec rake rubocop  # RuboCop only

# Run a single spec file
bundle exec rspec spec/lib/glancer/workflow/executor_spec.rb

# Run tests with coverage report
COVERAGE=1 bundle exec rspec
```

To iterate against a host Rails app, point the Gemfile to the local path:

```ruby
gem "glancer", path: "../glancer"
```

## Contributing

Bug reports, feature requests, and pull requests are welcome on [GitHub](https://github.com/ErnaneJ/glancer).

Before opening a pull request:

1. Fork the repository and create a feature branch from `main`.
2. Write or update tests for your changes — `bundle exec rake spec` must stay green.
3. Ensure RuboCop is clean — `bundle exec rake rubocop`.
4. Add an entry to `CHANGELOG.md` under `[Unreleased]`.
5. Open a pull request with a clear description of what changed and why.

Please read the [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## License

Glancer is available as open source under the [MIT License](LICENSE.txt).
