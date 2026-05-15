# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::SqlVersion do
  let(:chat)    { Glancer::Chat.create!(title: "Chat") }
  let(:message) { Glancer::Message.create!(chat: chat, role: "assistant", content: "result", sql: "SELECT 1") }

  subject(:sql_version) { described_class.new(message: message, sql: "SELECT 1", source: "generated") }

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with all required attributes" do
      expect(sql_version).to be_valid
    end

    it "is invalid without sql" do
      sql_version.sql = nil
      expect(sql_version).not_to be_valid
      expect(sql_version.errors[:sql]).to be_present
    end

    it "is invalid without source" do
      sql_version.source = nil
      expect(sql_version).not_to be_valid
    end
  end

  # ── Enum: source ─────────────────────────────────────────────────────────

  describe "source enum" do
    it "accepts 'generated'" do
      sv = described_class.create!(message: message, sql: "SELECT 1", source: "generated")
      expect(sv.generated?).to be(true)
    end

    it "accepts 'user_edited'" do
      sv = described_class.create!(message: message, sql: "SELECT 2", source: "user_edited")
      expect(sv.user_edited?).to be(true)
    end

    it "raises on an invalid source" do
      expect { described_class.create!(message: message, sql: "SELECT 1", source: "unknown") }
        .to raise_error(ArgumentError)
    end
  end

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    it "belongs_to a message" do
      sv = described_class.create!(message: message, sql: "SELECT 1", source: "generated")
      expect(sv.message).to eq(message)
    end
  end

  # ── Persistence ───────────────────────────────────────────────────────────

  describe "persistence" do
    it "increments count on create!" do
      expect { described_class.create!(message: message, sql: "SELECT 1", source: "generated") }
        .to change(described_class, :count).by(1)
    end

    it "stores the SQL content" do
      sv = described_class.create!(message: message, sql: "SELECT id FROM users", source: "generated")
      expect(sv.reload.sql).to eq("SELECT id FROM users")
    end
  end
end
