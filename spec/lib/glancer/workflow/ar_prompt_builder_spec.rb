# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::ARPromptBuilder do
  let(:chat)       { Glancer::Chat.create!(title: "Chat") }
  let(:embeddings) { [] }
  let(:question)   { "How many active users?" }

  # ── .custom_instructions_block ────────────────────────────────────────────

  describe ".custom_instructions_block" do
    it "returns an empty string when no custom instructions are set" do
      expect(described_class.custom_instructions_block).to eq("")
    end

    it "returns the instructions wrapped in a header when set" do
      Glancer::Setting.set("custom_instructions", "Always respond in Portuguese.")
      result = described_class.custom_instructions_block
      expect(result).to include("Always respond in Portuguese.")
      expect(result).to include("CUSTOM RULES")
    end

    it "returns an empty string when Setting.get raises" do
      allow(Glancer::Setting).to receive(:get).and_raise(StandardError, "db error")
      expect(described_class.custom_instructions_block).to eq("")
    end
  end

  # ── .call ─────────────────────────────────────────────────────────────────

  describe ".call" do
    it "returns a String" do
      result = described_class.call(question, embeddings)
      expect(result).to be_a(String)
    end

    it "includes the question in the prompt" do
      result = described_class.call(question, embeddings)
      expect(result).to include(question)
    end

    it "includes the schema context from embeddings" do
      embedding = Glancer::Embedding.new(content: "create_table users ...")
      result = described_class.call(question, [embedding])
      expect(result).to include("create_table users")
    end

    it "includes user history messages" do
      msg = Glancer::Message.create!(chat: chat, role: :user, content: "prior question")
      result = described_class.call(question, embeddings, history: [msg])
      expect(result).to include("prior question")
    end

    it "formats assistant messages with code in history" do
      msg = Glancer::Message.create!(
        chat: chat, role: :assistant, content: "There are 5.",
        code: "User.count", code_type: "activerecord"
      )
      result = described_class.call(question, embeddings, history: [msg])
      expect(result).to include("User.count")
      expect(result).to include("There are 5.")
    end

    it "formats assistant messages without code in history" do
      msg = Glancer::Message.create!(
        chat: chat, role: :assistant, content: "I couldn't process that.", code: nil
      )
      result = described_class.call(question, embeddings, history: [msg])
      expect(result).to include("I couldn't process that.")
    end

    it "raises Glancer::Error when building fails" do
      allow(Time).to receive(:current).and_raise(StandardError, "time error")
      expect { described_class.call(question, embeddings) }
        .to raise_error(Glancer::Error, /AR prompt construction failed/)
    end
  end
end
