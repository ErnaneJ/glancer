# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow do
  # ── Common doubles ────────────────────────────────────────────────────────

  let(:question) { "How many users are there?" }
  let(:sql)      { "SELECT COUNT(*) AS cnt FROM users" }
  let(:chat)     { Glancer::Chat.create!(title: "Test Chat") }

  let(:embedding) do
    Glancer::Embedding.create!(
      content: "create_table users ...",
      embedding: [0.1, 0.2, 0.3],
      source_type: "schema",
      source_path: "db/schema.rb#users"
    ).tap do |e|
      # Workflow.run calls e.score on each embedding from Retriever.search.
      # Retriever.search attaches score via define_singleton_method; add it here too.
      e.define_singleton_method(:score) { 1.3 }
    end
  end

  let(:fake_embed_response) { double("EmbedResponse", vectors: [0.1, 0.2, 0.3]) }
  let(:fake_sql_response)   { double("SqlResponse",   content: "```sql\n#{sql}\n```") }
  let(:fake_chat_response)  { double("ChatResponse",  content: "There are 42 users.") }

  let(:fake_llm_chat) do
    double("Chat").tap do |c|
      allow(c).to receive(:ask).and_return(fake_sql_response)
      allow(c).to receive(:with_instructions).and_return(c)
    end
  end

  let(:fake_humanize_chat) do
    double("HumanizeChat").tap do |c|
      allow(c).to receive(:ask).and_return(fake_chat_response)
      allow(c).to receive(:with_instructions).and_return(c)
    end
  end

  before do
    embedding # ensure it is persisted

    allow(RubyLLM).to receive(:embed).and_return(fake_embed_response)
    allow(RubyLLM).to receive(:chat).and_return(fake_llm_chat)
  end

  # Helper to stub the humanized response separately
  def stub_humanize_separately
    call_count = 0
    allow(RubyLLM).to receive(:chat) do
      call_count += 1
      call_count == 1 ? fake_llm_chat : fake_humanize_chat
    end
  end

  # ── Cache hit ─────────────────────────────────────────────────────────────

  describe ".run — cache hit" do
    before do
      Glancer::Workflow::Cache.write(question, {
                                       question: question,
                                       content: "Cached answer",
                                       code: sql,
                                       code_type: "sql",
                                       successful: true
                                     })
    end

    it "returns the cached result when cache: true (default)" do
      result = described_class.run(chat.id, question, cache: true)
      expect(result[:content]).to eq("Cached answer")
    end

    it "includes from_cache: true in the returned hash" do
      result = described_class.run(chat.id, question, cache: true)
      expect(result[:from_cache]).to be(true)
    end

    it "skips the LLM entirely when a cache hit is available" do
      expect(RubyLLM).not_to receive(:chat)
      described_class.run(chat.id, question, cache: true)
    end

    it "bypasses the cache when cache: false" do
      # cache: false → LLM is called
      expect(Glancer::Retriever).to receive(:search).and_return([embedding])
      allow(Glancer::Workflow::Builder).to receive(:build_sql).and_return(sql)
      allow(Glancer::Workflow::SQLValidator).to receive(:validate_tables_exist!)
      allow(Glancer::Workflow::Executor).to receive(:execute).and_return([{ "cnt" => 42 }])
      allow(Glancer::Workflow::LLM).to receive(:humanized_response).and_return("42 users")

      result = described_class.run(chat.id, question, cache: false)
      expect(result[:from_cache]).to be_nil
    end
  end

  # ── Full happy path ───────────────────────────────────────────────────────

  describe ".run — full pipeline" do
    before do
      # Seed the users table in the schema embeddings so validation passes
      Glancer::Workflow::Cache.clear

      allow(Glancer::Retriever).to receive(:search).and_return([embedding])
      allow(Glancer::Workflow::Builder).to receive(:build_sql).and_return("```sql\n#{sql}\n```")
      allow(Glancer::Workflow::SQLValidator).to receive(:validate_tables_exist!)
      allow(Glancer::Workflow::Executor).to receive(:execute).and_return([{ "cnt" => 42 }])
      allow(Glancer::Workflow::LLM).to receive(:humanized_response).and_return("There are 42 users.")
    end

    it "returns a hash with :question" do
      result = described_class.run(chat.id, question)
      expect(result[:question]).to eq(question)
    end

    it "returns :successful true on success" do
      result = described_class.run(chat.id, question)
      expect(result[:successful]).to be(true)
    end

    it "returns :code with the extracted SQL" do
      result = described_class.run(chat.id, question)
      expect(result[:code]).to include("SELECT")
    end

    it "returns :content with the humanized response" do
      result = described_class.run(chat.id, question)
      expect(result[:content]).to eq("There are 42 users.")
    end

    it "returns :sources array from the embeddings" do
      result = described_class.run(chat.id, question)
      expect(result[:sources]).to be_an(Array)
      expect(result[:sources].first).to have_key(:type)
    end

    it "writes the result to cache when cache: true" do
      described_class.run(chat.id, question, cache: true)
      cached = Glancer::Workflow::Cache.fetch(question)
      expect(cached).not_to be_nil
    end

    it "does not write to cache when cache: false" do
      described_class.run(chat.id, question, cache: false)
      expect(Glancer::Workflow::Cache.fetch(question)).to be_nil
    end
  end

  # ── Table validation failure ───────────────────────────────────────────────

  describe ".run — table validation failure" do
    before do
      Glancer::Workflow::Cache.clear

      allow(Glancer::Retriever).to receive(:search).and_return([embedding])
      allow(Glancer::Workflow::Builder).to receive(:build_sql).and_return(sql)
      allow(Glancer::Workflow::SQLValidator)
        .to receive(:validate_tables_exist!)
        .and_raise(Glancer::Error, "Missing table(s) in indexed schema: users")
      allow(Glancer::Workflow::LLM)
        .to receive(:explain_missing_tables)
        .and_return("The table 'users' was not found in the schema.")
    end

    it "returns :successful false" do
      result = described_class.run(chat.id, question)
      expect(result[:successful]).to be(false)
    end

    it "returns an explanation in :content" do
      result = described_class.run(chat.id, question)
      expect(result[:content]).to include("users")
    end

    it "includes the code that failed validation" do
      result = described_class.run(chat.id, question)
      expect(result[:code]).to be_a(String)
    end
  end

  # ── Execution failure ─────────────────────────────────────────────────────

  describe ".run — execution failure after retries" do
    before do
      Glancer::Workflow::Cache.clear

      allow(Glancer::Retriever).to receive(:search).and_return([embedding])
      allow(Glancer::Workflow::Builder).to receive(:build_sql).and_return(sql)
      allow(Glancer::Workflow::SQLValidator).to receive(:validate_tables_exist!)
      allow(Glancer::Workflow::Executor).to receive(:execute).and_return(
        { error: true, message: "no such table: users", last_code: sql }
      )
      allow(Glancer::Workflow::LLM)
        .to receive(:explain_error)
        .and_return("I couldn't process the query after 3 attempts.")
    end

    it "returns :successful false" do
      result = described_class.run(chat.id, question)
      expect(result[:successful]).to be(false)
    end

    it "returns the error explanation in :content" do
      result = described_class.run(chat.id, question)
      expect(result[:content]).to include("3 attempts")
    end
  end

  # ── Sanitization blocks the pipeline ─────────────────────────────────────

  describe ".run — SQL sanitizer blocks execution" do
    before do
      Glancer::Workflow::Cache.clear

      allow(Glancer::Retriever).to receive(:search).and_return([embedding])
      # LLM returns a DROP statement (malicious)
      allow(Glancer::Workflow::Builder).to receive(:build_sql).and_return("DROP TABLE users")
    end

    it "raises Glancer::Error (via the sanitizer)" do
      expect { described_class.run(chat.id, question) }.to raise_error(Glancer::Error)
    end
  end

  # ── chat not found ────────────────────────────────────────────────────────

  describe ".run — chat not found" do
    it "raises Glancer::Error wrapping the ActiveRecord error" do
      expect { described_class.run(999_999, question) }.to raise_error(Glancer::Error)
    end
  end

  # ── ActiveRecord mode ─────────────────────────────────────────────────────

  describe ".run — activerecord pipeline" do
    let(:ar_code) { "Glancer::Chat.count" }

    before do
      Glancer::Workflow::Cache.clear
      Glancer.configuration.query_mode = :activerecord

      allow(Glancer::Retriever).to receive(:search).and_return([embedding])
      allow(Glancer::Workflow::Builder).to receive(:build_ar_code).and_return("```ruby\n#{ar_code}\n```")
      allow(Glancer::Workflow::ARExecutor).to receive(:execute).and_return([{ "result" => 0 }])
      allow(Glancer::Workflow::LLM).to receive(:humanized_response).and_return("Zero chats.")
    end

    after { Glancer.configuration.query_mode = :sql }

    it "returns :successful true" do
      result = described_class.run(chat.id, question)
      expect(result[:successful]).to be(true)
    end

    it "returns code_type 'activerecord'" do
      result = described_class.run(chat.id, question)
      expect(result[:code_type]).to eq("activerecord")
    end

    it "returns the humanized content" do
      result = described_class.run(chat.id, question)
      expect(result[:content]).to eq("Zero chats.")
    end

    it "returns :successful false and explanation when AR executor reports an error" do
      allow(Glancer::Workflow::ARExecutor).to receive(:execute).and_return(
        { error: true, message: "undefined constant", last_code: ar_code }
      )
      allow(Glancer::Workflow::LLM).to receive(:explain_error).and_return("I couldn't fix it.")
      result = described_class.run(chat.id, question)
      expect(result[:successful]).to be(false)
      expect(result[:content]).to eq("I couldn't fix it.")
    end
  end

  # ── enrich_question ───────────────────────────────────────────────────────

  describe ".run — question enrichment enabled" do
    before do
      Glancer::Workflow::Cache.clear
      Glancer.configuration.query_enrichment_enabled = true

      allow(Glancer::Retriever).to receive(:search).and_return([embedding])
      allow(Glancer::Workflow::Builder).to receive(:build_sql).and_return("```sql\n#{sql}\n```")
      allow(Glancer::Workflow::SQLValidator).to receive(:validate_tables_exist!)
      allow(Glancer::Workflow::Executor).to receive(:execute).and_return([{ "cnt" => 42 }])
      allow(Glancer::Workflow::LLM).to receive(:humanized_response).and_return("42 users.")
      allow(Glancer::Workflow::QueryEnricher).to receive(:known_table_names).and_return(["users"])
      allow(Glancer::Workflow::QueryEnricher).to receive(:enrich).and_return("enriched: #{question}")
    end

    after { Glancer.configuration.query_enrichment_enabled = false }

    it "stores enriched_question in the result" do
      result = described_class.run(chat.id, question)
      expect(result[:enriched_question]).to eq("enriched: #{question}")
    end

    it "falls back to the original question when enrichment raises" do
      allow(Glancer::Workflow::QueryEnricher).to receive(:enrich).and_raise(StandardError, "LLM timeout")
      result = described_class.run(chat.id, question)
      expect(result[:enriched_question]).to eq(question)
    end
  end
end
