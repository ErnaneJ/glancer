# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::Builder do
  let(:fake_response) { double("Response", content: "SELECT * FROM users") }
  let(:fake_chat) do
    double("Chat").tap do |c|
      allow(c).to receive(:ask).and_return(fake_response)
      allow(c).to receive(:with_instructions).and_return(c)
    end
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(fake_chat)
  end

  # ── .build_sql ────────────────────────────────────────────────────────────

  describe ".build_sql" do
    let(:question)   { "Show all users" }
    let(:embeddings) { [] }

    it "returns the SQL content from the LLM response" do
      result = described_class.build_sql(question, embeddings)
      expect(result).to eq("SELECT * FROM users")
    end

    it "calls RubyLLM.chat with the configured provider and model" do
      expect(RubyLLM).to receive(:chat).with(
        hash_including(provider: Glancer.configuration.resolved_sql_provider,
                       model: Glancer.configuration.resolved_sql_model)
      ).and_return(fake_chat)
      described_class.build_sql(question, embeddings)
    end

    it "passes history to the prompt builder" do
      chat = Glancer::Chat.create!(title: "C")
      msg  = Glancer::Message.create!(chat: chat, role: "user", content: "previous Q")
      described_class.build_sql(question, embeddings, history: [msg])
      # No error means history was processed
    end

    it "raises Glancer::Error when the LLM call fails" do
      allow(RubyLLM).to receive(:chat).and_raise(StandardError, "network error")
      expect { described_class.build_sql(question, embeddings) }
        .to raise_error(Glancer::Error, /SQL generation failed/)
    end

    it "includes recent audit examples as few-shot examples" do
      Glancer::Audit.create!(
        question: "How many users?",
        sql: "SELECT COUNT(*) FROM users /*glancer,run_id:abc*/",
        adapter: Glancer.configuration.resolved_adapter.to_s,
        run_id: SecureRandom.uuid,
        executed_at: Time.current
      )
      expect(fake_chat).to receive(:ask).and_return(fake_response)
      described_class.build_sql(question, embeddings)
    end
  end

  # ── .recent_examples ──────────────────────────────────────────────────────

  describe ".recent_examples" do
    it "returns an empty array when no audits exist" do
      expect(described_class.recent_examples).to eq([])
    end

    it "returns up to 3 most recent audit pairs [question, sql]" do
      4.times do |i|
        Glancer::Audit.create!(
          question: "Q#{i}",
          sql: "SELECT #{i}",
          adapter: Glancer.configuration.resolved_adapter.to_s,
          run_id: SecureRandom.uuid,
          executed_at: Time.current - (4 - i).seconds
        )
      end
      examples = described_class.recent_examples
      expect(examples.size).to eq(3)
      # Most recent first
      expect(examples.first[0]).to eq("Q3")
    end

    it "only returns audits matching the current adapter" do
      Glancer::Audit.create!(
        question: "PostgreSQL Q",
        sql: "SELECT 1",
        adapter: "postgres",
        run_id: SecureRandom.uuid,
        executed_at: Time.current
      )
      # SQLite adapter in tests — postgres audit should NOT appear
      expect(described_class.recent_examples).to be_empty
    end

    it "excludes audits without a question" do
      Glancer::Audit.create!(
        question: nil,
        sql: "SELECT 1",
        adapter: Glancer.configuration.resolved_adapter.to_s,
        run_id: SecureRandom.uuid,
        executed_at: Time.current
      )
      expect(described_class.recent_examples).to be_empty
    end
  end

  # ── .fix_sql ─────────────────────────────────────────────────────────────

  describe ".fix_sql" do
    let(:failed_sql)     { "SELCT * FROM users" }
    let(:error_message)  { "syntax error near SELCT" }
    let(:fixed_response) { double("Response", content: "```sql\nSELECT * FROM users\n```") }
    let(:fix_chat) do
      double("Chat").tap do |c|
        allow(c).to receive(:ask).and_return(fixed_response)
      end
    end

    before do
      allow(RubyLLM).to receive(:chat).and_return(fix_chat)
    end

    it "returns extracted SQL from the LLM's corrected response" do
      result = described_class.fix_sql(failed_sql, error_message)
      expect(result).to eq("SELECT * FROM users")
    end

    it "calls RubyLLM.chat to get the correction" do
      expect(RubyLLM).to receive(:chat).and_return(fix_chat)
      described_class.fix_sql(failed_sql, error_message)
    end

    it "raises Glancer::Error when the LLM call fails" do
      allow(RubyLLM).to receive(:chat).and_raise(StandardError, "LLM down")
      expect { described_class.fix_sql(failed_sql, error_message) }
        .to raise_error(Glancer::Error, /SQL correction workflow failed/)
    end
  end
end
