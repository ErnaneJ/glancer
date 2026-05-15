# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::PromptBuilder do
  let(:question)   { "How many users signed up this month?" }
  let(:embedding1) do
    Glancer::Embedding.create!(
      content: "create_table users ...",
      embedding: [],
      source_type: "schema",
      source_path: "db/schema.rb#users"
    )
  end
  let(:embedding2) do
    Glancer::Embedding.create!(
      content: "# Foreign Key Relationships\norders.user_id → users.id",
      embedding: [],
      source_type: "schema",
      source_path: "db/schema.rb#foreign_keys"
    )
  end
  let(:embeddings) { [embedding1, embedding2] }

  let(:chat)    { Glancer::Chat.create!(title: "Test") }
  let(:history) { [] }

  # Mock DB connection's current_database method
  before do
    allow(ActiveRecord::Base.connection).to receive(:current_database).and_return("test_db")
  end

  # ── .call ─────────────────────────────────────────────────────────────────

  describe ".call" do
    subject(:prompt) { described_class.call(question, embeddings, history: history) }

    it "returns a String" do
      expect(prompt).to be_a(String)
    end

    it "includes the question" do
      expect(prompt).to include(question)
    end

    it "includes the adapter type" do
      expect(prompt).to include("SQLITE")
    end

    it "includes schema content from embeddings" do
      expect(prompt).to include("create_table users")
    end

    it "places foreign key content in the SCHEMA RELATIONSHIPS section" do
      expect(prompt).to include("orders.user_id → users.id")
    end

    it "includes OUTPUT SQL ONLY directive" do
      expect(prompt).to include("OUTPUT SQL ONLY")
    end

    context "when history contains messages" do
      let(:user_msg) do
        Glancer::Message.create!(chat: chat, role: "user", content: "Show orders")
      end
      let(:assistant_msg) do
        Glancer::Message.create!(
          chat: chat, role: "assistant", content: "Here are the orders",
          sql: "SELECT * FROM orders"
        )
      end
      let(:history) { [user_msg, assistant_msg] }

      it "includes the user message in the conversation history" do
        expect(prompt).to include("Show orders")
      end

      it "includes the assistant SQL in the conversation history" do
        expect(prompt).to include("SELECT * FROM orders")
      end
    end

    context "when history is empty" do
      it "includes a placeholder for no prior messages" do
        expect(prompt).to include("no prior messages")
      end
    end

    context "when custom instructions are set" do
      before { Glancer::Setting.set("custom_instructions", "Always use LIMIT 100") }

      it "includes the custom instructions" do
        expect(prompt).to include("Always use LIMIT 100")
      end
    end

    it "raises Glancer::Error on unexpected failure" do
      allow(described_class).to receive(:format_embeddings_with_stats).and_raise(RuntimeError, "boom")
      expect { described_class.call(question, embeddings) }.to raise_error(Glancer::Error, /Prompt construction failed/)
    end
  end

  # ── .custom_instructions_block ────────────────────────────────────────────

  describe ".custom_instructions_block" do
    it "returns empty string when Glancer::Setting.get raises" do
      allow(Glancer::Setting).to receive(:get).and_raise(StandardError, "DB error")
      expect(described_class.custom_instructions_block).to eq("")
    end

    it "returns an empty string when no custom instructions are set" do
      expect(described_class.custom_instructions_block).to eq("")
    end

    it "returns the custom instructions block when set" do
      Glancer::Setting.set("custom_instructions", "Use snake_case")
      result = described_class.custom_instructions_block
      expect(result).to include("Use snake_case")
      expect(result).to include("CUSTOM RULES")
    end
  end

  # ── .partition_embeddings ─────────────────────────────────────────────────

  describe ".partition_embeddings" do
    it "separates FK embeddings from regular embeddings" do
      schema_embeds, fk_text = described_class.partition_embeddings(embeddings)
      expect(schema_embeds).to include(embedding1)
      expect(schema_embeds).not_to include(embedding2)
      expect(fk_text).to include("Foreign Key Relationships")
    end

    it "returns empty FK text when no FK embeddings exist" do
      _schema_embeds, fk_text = described_class.partition_embeddings([embedding1])
      expect(fk_text).to eq("")
    end
  end

  # ── .format_embeddings_with_stats ─────────────────────────────────────────

  describe ".format_embeddings_with_stats" do
    it "joins the content of each embedding with double newlines" do
      result = described_class.format_embeddings_with_stats([embedding1])
      expect(result).to include("create_table users")
    end
  end

  # ── .format_few_shot_examples ─────────────────────────────────────────────

  describe ".format_few_shot_examples" do
    it "returns empty string for empty examples" do
      expect(described_class.format_few_shot_examples([])).to eq("")
    end

    it "formats examples with question and SQL" do
      examples = [["Count users", "SELECT COUNT(*) FROM users"]]
      result   = described_class.format_few_shot_examples(examples)
      expect(result).to include("Count users")
      expect(result).to include("SELECT COUNT(*) FROM users")
    end

    it "numbers examples starting from 1" do
      examples = [
        ["Q1", "SELECT 1"],
        ["Q2", "SELECT 2"]
      ]
      result = described_class.format_few_shot_examples(examples)
      expect(result).to include("Example 1:")
      expect(result).to include("Example 2:")
    end
  end

  # ── .example_sql ─────────────────────────────────────────────────────────

  describe ".example_sql" do
    it "returns MySQL example for mysql adapter" do
      result = described_class.example_sql("mysql")
      expect(result).to include("DATE_FORMAT")
    end

    it "returns MySQL example for mysql2 adapter" do
      result = described_class.example_sql("mysql2")
      expect(result).to include("DATE_FORMAT")
    end

    it "returns PostgreSQL example for postgres adapter" do
      result = described_class.example_sql("postgres")
      expect(result).to include("TO_CHAR")
    end

    it "returns a fallback comment for unsupported adapters" do
      result = described_class.example_sql("sqlite")
      expect(result).to include("Example not available")
    end
  end
end
