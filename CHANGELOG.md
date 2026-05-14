# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-14

### Added

- **RAG pipeline**: embed → retrieve → generate SQL → execute → humanize, with automatic
  retry (up to 3 attempts) on SQL errors using LLM self-correction.
- **Multi-provider LLM support** via [ruby_llm](https://github.com/crmne/ruby_llm):
  Gemini, OpenAI, and OpenRouter. Each role (SQL generation, chat responses, embeddings)
  can use a different provider and model.
- **Indexers** for `db/schema.rb`, `app/models/**/*.rb`, and a custom Markdown context
  file. Rake tasks: `glancer:index:all`, `glancer:index:schema`, `glancer:index:models`,
  `glancer:index:context`.
- **Cosine similarity retrieval** with per-source-type relevance weights (schema 1.3×,
  context 1.2×, models 1.1×) and a configurable minimum score threshold.
- **Chunk overlap** to prevent context loss at document boundaries.
- **SQL safety layer**: `SQLSanitizer` (blocks destructive statements),
  `SQLValidator` (verifies table references against indexed schema), and
  mandatory read-only transaction with automatic rollback.
- **Audit trail**: every executed query is stored in `glancer_audits` with a unique
  `run_id` UUID injected as an SQL comment (`/*glancer,run_id:UUID*/`).
- **Blazer integration**: auto-detected when the `blazer` gem is present; configurable
  via `config.blazer_path`.
- **In-memory response cache** (`workflow_cache_ttl`) to avoid redundant LLM calls for
  repeated identical questions.
- **Chat UI**: Stimulus + Turbo Streams interface with dark mode, typewriter effect,
  CSV export, SQL re-run, SQL editing with user-edit badge, pipeline status labels,
  accordion results, copy-to-clipboard, and audio input (Web Speech API).
- **Settings page** at `/glancer/settings` for runtime custom instructions.
- **Schema viewer** at `/glancer/db-schema` showing indexed tables and columns.
- **Install generator**: `rails generate glancer:install` scaffolds the initializer,
  context file, and mounts the engine.
- Configurable `statement_timeout` enforced via adapter-native mechanisms
  (PostgreSQL `SET statement_timeout`, MySQL `SET max_execution_time`).
- `config.history_limit` to control how many prior turns are included in the prompt.
- `config.read_only_db` to route queries to a replica connection string.

[Unreleased]: https://github.com/ernanej/glancer/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ernanej/glancer/releases/tag/v0.1.0
