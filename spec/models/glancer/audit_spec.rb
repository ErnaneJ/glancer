# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Audit do
  let(:valid_attrs) do
    {
      sql: "SELECT 1 /*glancer,run_id:abc*/",
      adapter: "sqlite",
      run_id: SecureRandom.uuid,
      executed_at: Time.current
    }
  end

  subject(:audit) { described_class.new(valid_attrs) }

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with all required attributes" do
      expect(audit).to be_valid
    end

    it "is invalid without sql" do
      audit.sql = nil
      expect(audit).not_to be_valid
      expect(audit.errors[:sql]).to be_present
    end

    it "is invalid without adapter" do
      audit.adapter = nil
      expect(audit).not_to be_valid
    end

    it "is invalid without run_id" do
      audit.run_id = nil
      expect(audit).not_to be_valid
    end

    it "is invalid without executed_at" do
      audit.executed_at = nil
      expect(audit).not_to be_valid
    end

    it "enforces uniqueness of run_id" do
      uuid = SecureRandom.uuid
      described_class.create!(valid_attrs.merge(run_id: uuid))
      duplicate = described_class.new(valid_attrs.merge(run_id: uuid))
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:run_id]).to be_present
    end
  end

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    it "belongs_to message optionally" do
      expect(audit).to be_valid # message_id is nil
    end

    it "links to a message when provided" do
      chat = Glancer::Chat.create!(title: "C")
      msg  = Glancer::Message.create!(chat: chat, role: "assistant", content: "x")
      audit.message = msg
      audit.save!
      expect(audit.reload.message).to eq(msg)
    end
  end

  # ── Persistence ───────────────────────────────────────────────────────────

  describe "persistence" do
    it "saves successfully with valid attributes" do
      expect { described_class.create!(valid_attrs) }.to change(described_class, :count).by(1)
    end

    it "stores the question (optional)" do
      a = described_class.create!(valid_attrs.merge(question: "How many users?"))
      expect(a.reload.question).to eq("How many users?")
    end
  end
end
