# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::QueryEnricher do
  let(:fake_response) { double("Response", content: "Show all records from users table") }
  let(:fake_chat) do
    double("Chat").tap { |c| allow(c).to receive(:ask).and_return(fake_response) }
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(fake_chat)
  end

  # ── .enrich ───────────────────────────────────────────────────────────────

  describe ".enrich" do
    let(:question)    { "Mostre todas as vendas" }
    let(:table_names) { %w[orders users products] }

    it "returns the LLM-enriched question" do
      result = described_class.enrich(question, table_names)
      expect(result).to eq("Show all records from users table")
    end

    it "passes provider and model from configuration" do
      expect(RubyLLM).to receive(:chat).with(
        hash_including(
          provider: Glancer.configuration.resolved_enrichment_provider,
          model: Glancer.configuration.resolved_enrichment_model
        )
      ).and_return(fake_chat)
      described_class.enrich(question, table_names)
    end

    it "returns the original question when table_names is empty" do
      expect(RubyLLM).not_to receive(:chat)
      result = described_class.enrich(question, [])
      expect(result).to eq(question)
    end

    it "returns the original question when the LLM call fails" do
      allow(RubyLLM).to receive(:chat).and_raise(StandardError, "network error")
      result = described_class.enrich(question, table_names)
      expect(result).to eq(question)
    end

    it "returns the original question when LLM returns blank content" do
      allow(fake_chat).to receive(:ask).and_return(double("Response", content: "   "))
      result = described_class.enrich(question, table_names)
      expect(result).to eq(question)
    end

    it "includes the table names in the prompt sent to the LLM" do
      expect(fake_chat).to receive(:ask) do |prompt|
        expect(prompt).to include("orders")
        expect(prompt).to include("users")
        fake_response
      end
      described_class.enrich(question, table_names)
    end

    it "strips whitespace from the enriched question" do
      allow(fake_chat).to receive(:ask).and_return(double("Response", content: "  enriched question  "))
      result = described_class.enrich(question, table_names)
      expect(result).to eq("enriched question")
    end

    it "includes assistant messages with code in the history block sent to the LLM" do
      chat_obj = Glancer::Chat.create!(title: "T")
      msg = Glancer::Message.create!(
        chat: chat_obj, role: :assistant, content: "Found 3.",
        code: "User.count", code_type: "activerecord"
      )
      expect(fake_chat).to receive(:ask) do |prompt|
        expect(prompt).to include("ASSISTANT")
        expect(prompt).to include("User.count")
        fake_response
      end
      described_class.enrich(question, table_names, history: [msg])
    end

    it "includes non-code messages in the history block without code format" do
      chat_obj = Glancer::Chat.create!(title: "T")
      msg = Glancer::Message.create!(chat: chat_obj, role: :user, content: "What is the count?")
      expect(fake_chat).to receive(:ask) do |prompt|
        expect(prompt).to include("USER: What is the count?")
        fake_response
      end
      described_class.enrich(question, table_names, history: [msg])
    end

    it "includes referenced schema context in prompt when question has @mentioned tables" do
      Glancer::Embedding.create!(
        content: "create_table orders ...", embedding: [],
        source_type: "schema", source_path: "/db/schema.rb#orders"
      )
      expect(fake_chat).to receive(:ask) do |prompt|
        expect(prompt).to include("Referenced Schema")
        fake_response
      end
      described_class.enrich("How many @orders?", ["orders"])
    end

    it "continues normally when schema context lookup raises (rescue path)" do
      allow(Glancer::Embedding).to receive(:where).and_raise(StandardError, "db error")
      result = described_class.enrich("count @orders", ["orders"])
      expect(result).to be_a(String)
    end

    it "omits referenced schema block when @mention does not match any table" do
      expect(fake_chat).to receive(:ask) do |prompt|
        expect(prompt).not_to include("Referenced Schema")
        fake_response
      end
      described_class.enrich("How many @ghost records?", table_names)
    end
  end

  # ── .known_table_names ────────────────────────────────────────────────────

  describe ".known_table_names" do
    it "returns an empty array when no embeddings exist" do
      expect(described_class.known_table_names).to eq([])
    end

    it "extracts table names from schema embedding source_paths" do
      Glancer::Embedding.create!(
        content: "create_table users",
        embedding: [],
        source_type: "schema",
        source_path: "/fake/root/db/schema.rb#users"
      )
      expect(described_class.known_table_names).to include("users")
    end

    it "excludes the foreign_keys pseudo-table" do
      Glancer::Embedding.create!(
        content: "fk block",
        embedding: [],
        source_type: "schema",
        source_path: "/fake/root/db/schema.rb#foreign_keys"
      )
      expect(described_class.known_table_names).not_to include("foreign_keys")
    end

    it "excludes non-schema embeddings" do
      Glancer::Embedding.create!(
        content: "model content",
        embedding: [],
        source_type: "model",
        source_path: "app/models/user.rb"
      )
      expect(described_class.known_table_names).to be_empty
    end

    it "excludes inflections chunks (paths that contain /)" do
      Glancer::Embedding.create!(
        content: "inflections",
        embedding: [],
        source_type: "schema",
        source_path: "config/initializers/inflections.rb"
      )
      expect(described_class.known_table_names).to be_empty
    end

    it "deduplicates table names" do
      2.times do
        Glancer::Embedding.create!(
          content: "table",
          embedding: [],
          source_type: "schema",
          source_path: "/fake/db/schema.rb#orders"
        )
      end
      expect(described_class.known_table_names.count("orders")).to eq(1)
    end

    it "returns [] when the DB query raises" do
      allow(Glancer::Embedding).to receive(:where).and_raise(StandardError, "db error")
      expect(described_class.known_table_names).to eq([])
    end
  end
end
