# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-05-24

First public release.

### Added

- **RAG pipeline**: embed → retrieve → generate code → validate → execute → humanize,
  with automatic retry (up to 3 attempts) on errors using LLM self-correction.
- **Dual query mode**: `query_mode: :sql` (default) generates read-only SQL;
  `query_mode: :activerecord` generates and evaluates Ruby/ActiveRecord expressions.
  Each mode has its own sanitizer (`SQLSanitizer` / `ARSanitizer`), extractor, prompt
  builder, and executor.
- **Multi-provider LLM support** via [ruby_llm](https://github.com/crmne/ruby_llm):
  Gemini, OpenAI, and OpenRouter. Code generation, chat responses, and embeddings can
  each use a different provider and model.
- **Async message processing** via `Glancer::AsyncRunner`: messages are processed in a
  background thread using `connection_pool.with_connection` — no external job queue
  (Sidekiq, GoodJob, etc.) required.
- **Client-side polling**: the UI polls `/messages/:id/poll` every 2 s and replaces the
  message partial via Turbo Stream once done; a 5-minute hard timeout marks stuck
  messages as failed automatically.
- **Query enrichment**: `QueryEnricher` translates natural-language questions into dense
  technical specifications before retrieval, improving code accuracy.
- **Indexers** for `db/schema.rb`, `app/models/**/*.rb`, and a custom Markdown context
  file. Rake tasks: `glancer:index:all`, `glancer:index:schema`, `glancer:index:models`,
  `glancer:index:context`.
- **Cosine similarity retrieval** with per-source-type relevance weights (schema 1.3×,
  context 1.2×, models 1.1×), configurable minimum score threshold, and fallback to
  top-k results when no embedding meets the threshold.
- **SQL safety layer**: `SQLSanitizer` (blocks destructive statements),
  `SQLValidator` (verifies table references against indexed schema), and mandatory
  read-only transaction with automatic rollback.
- **Audit trail**: every executed query is stored in `glancer_audits` with a unique
  `run_id` UUID injected as a comment (`/*glancer,run_id:UUID*/`).
- **In-memory response cache** (`workflow_cache_ttl`) to avoid redundant LLM calls for
  repeated identical questions.
- **Chat UI**: Stimulus + Turbo Streams interface with dark mode, typewriter effect,
  CSV export, SQL/AR re-run, chart visualizations (bar, line, pie), client-side polling,
  pipeline status labels, accordion results, and copy-to-clipboard.
- **Settings page** at `/glancer/settings` for runtime custom instructions.
- **Schema viewer** at `/glancer/db-schema` showing indexed tables and columns.
- **Install generator**: `rails generate glancer:install` scaffolds the initializer,
  context file, and mounts the engine.
- Configurable `statement_timeout`, `history_limit`, `read_only_db`, `k`, `min_score`,
  and per-source document weights.
- **100% line coverage**: 717 RSpec examples covering every workflow path, edge case,
  and rescue branch.

[Unreleased]: https://github.com/ErnaneJ/glancer/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ErnaneJ/glancer/releases/tag/v1.0.0
