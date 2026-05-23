# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::CodeVersion do
  let(:chat)    { Glancer::Chat.create!(title: "Chat") }
  let(:message) { Glancer::Message.create!(chat: chat, role: "assistant", content: "result", code: "SELECT 1") }

  subject(:code_version) { described_class.new(message: message, code: "SELECT 1", source: "generated") }

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with all required attributes" do
      expect(code_version).to be_valid
    end

    it "is invalid without code" do
      code_version.code = nil
      expect(code_version).not_to be_valid
      expect(code_version.errors[:code]).to be_present
    end

    it "is invalid without source" do
      code_version.source = nil
      expect(code_version).not_to be_valid
    end
  end

  # ── Enum: source ─────────────────────────────────────────────────────────

  describe "source enum" do
    it "accepts 'generated'" do
      sv = described_class.create!(message: message, code: "SELECT 1", source: "generated")
      expect(sv.generated?).to be(true)
    end

    it "accepts 'user_edited'" do
      sv = described_class.create!(message: message, code: "SELECT 2", source: "user_edited")
      expect(sv.user_edited?).to be(true)
    end

    it "raises on an invalid source" do
      expect { described_class.create!(message: message, code: "SELECT 1", source: "unknown") }
        .to raise_error(ArgumentError)
    end
  end

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    it "belongs_to a message" do
      sv = described_class.create!(message: message, code: "SELECT 1", source: "generated")
      expect(sv.message).to eq(message)
    end
  end

  # ── Persistence ───────────────────────────────────────────────────────────

  describe "persistence" do
    it "increments count on create!" do
      expect { described_class.create!(message: message, code: "SELECT 1", source: "generated") }
        .to change(described_class, :count).by(1)
    end

    it "stores the code content" do
      sv = described_class.create!(message: message, code: "SELECT id FROM users", source: "generated")
      expect(sv.reload.code).to eq("SELECT id FROM users")
    end
  end
end
