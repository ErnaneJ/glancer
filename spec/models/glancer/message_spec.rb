# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Message do
  let(:chat)         { Glancer::Chat.create!(title: "Test Chat") }
  let(:user_message) { described_class.create!(chat: chat, role: "user", content: "How many orders?") }

  subject(:message) { described_class.new(chat: chat, role: "user", content: "Hello") }

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with required attributes" do
      expect(message).to be_valid
    end

    it "is invalid without content" do
      message.content = nil
      expect(message).not_to be_valid
      expect(message.errors[:content]).to include("can't be blank")
    end

    it "is invalid with an empty content string" do
      message.content = ""
      expect(message).not_to be_valid
    end
  end

  # ── Enum: role ────────────────────────────────────────────────────────────

  describe "role enum" do
    it "accepts 'user'" do
      msg = described_class.create!(chat: chat, role: "user", content: "hi")
      expect(msg.role).to eq("user")
      expect(msg.user?).to be(true)
    end

    it "accepts 'assistant'" do
      msg = described_class.create!(chat: chat, role: "assistant", content: "hello")
      expect(msg.role).to eq("assistant")
      expect(msg.assistant?).to be(true)
    end

    it "accepts 'system'" do
      msg = described_class.create!(chat: chat, role: "system", content: "init")
      expect(msg.role).to eq("system")
      expect(msg.system?).to be(true)
    end

    it "raises on an invalid role" do
      expect { described_class.create!(chat: chat, role: "unknown", content: "x") }
        .to raise_error(ArgumentError)
    end
  end

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    it "belongs_to a chat" do
      expect(user_message.chat).to eq(chat)
    end

    it "belongs_to a user_message (optional)" do
      assistant = described_class.create!(
        chat: chat,
        role: "assistant",
        content: "There are 10 orders.",
        user_message: user_message
      )
      expect(assistant.user_message).to eq(user_message)
    end

    it "allows nil user_message (optional association)" do
      msg = described_class.create!(chat: chat, role: "user", content: "test")
      expect(msg.user_message).to be_nil
    end

    it "has many sql_versions" do
      msg = described_class.create!(chat: chat, role: "assistant", content: "result", sql: "SELECT 1")
      version = Glancer::SqlVersion.create!(message: msg, sql: "SELECT 1", source: "generated")
      expect(msg.sql_versions).to include(version)
    end

    it "destroys sql_versions when the message is destroyed" do
      msg = described_class.create!(chat: chat, role: "assistant", content: "result", sql: "SELECT 1")
      Glancer::SqlVersion.create!(message: msg, sql: "SELECT 1", source: "generated")
      expect { msg.destroy }.to change(Glancer::SqlVersion, :count).by(-1)
    end

    it "nullifies audits when the message is destroyed" do
      msg = described_class.create!(chat: chat, role: "assistant", content: "result", sql: "SELECT 1")
      audit = Glancer::Audit.create!(
        sql: "SELECT 1",
        adapter: "sqlite",
        run_id: SecureRandom.uuid,
        executed_at: Time.current,
        message: msg
      )
      msg.destroy
      expect(audit.reload.message_id).to be_nil
    end
  end

  # ── before_destroy callback ───────────────────────────────────────────────

  describe "before_destroy callback" do
    it "nullifies user_message_id on assistant messages pointing to this user message" do
      assistant = described_class.create!(
        chat: chat,
        role: "assistant",
        content: "reply",
        user_message: user_message
      )

      user_message.destroy
      expect(assistant.reload.user_message_id).to be_nil
    end
  end

  # ── #sql_result_json ──────────────────────────────────────────────────────

  describe "#sql_result_json" do
    it "parses valid JSON content" do
      msg = described_class.new(content: '[{"id":1}]')
      expect(msg.sql_result_json).to eq([{ "id" => 1 }])
    end

    it "returns [] for non-JSON content" do
      msg = described_class.new(content: "plain text response")
      expect(msg.sql_result_json).to eq([])
    end

    it "returns [] for nil content" do
      msg = described_class.new(content: nil)
      expect(msg.sql_result_json).to eq([])
    end

    it "returns [] for malformed JSON" do
      msg = described_class.new(content: "{bad json}")
      expect(msg.sql_result_json).to eq([])
    end
  end
end
