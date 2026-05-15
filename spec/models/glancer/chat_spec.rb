# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Chat do
  subject(:chat) { described_class.new(title: "Test Chat") }

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with a title" do
      expect(chat).to be_valid
    end

    it "is invalid without a title" do
      chat.title = nil
      expect(chat).not_to be_valid
      expect(chat.errors[:title]).to include("can't be blank")
    end

    it "is invalid with an empty title string" do
      chat.title = ""
      expect(chat).not_to be_valid
    end
  end

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    let!(:saved_chat) { described_class.create!(title: "Chat") }

    it "has many messages" do
      msg = Glancer::Message.create!(chat: saved_chat, role: "user", content: "Hello")
      expect(saved_chat.messages).to include(msg)
    end

    it "destroys associated messages when the chat is destroyed" do
      Glancer::Message.create!(chat: saved_chat, role: "user", content: "Hello")
      expect { saved_chat.destroy }.to change(Glancer::Message, :count).by(-1)
    end
  end

  # ── Persistence ───────────────────────────────────────────────────────────

  describe "persistence" do
    it "can be saved" do
      expect(chat.save).to be(true)
    end

    it "increments the count on create!" do
      expect { described_class.create!(title: "New") }.to change(described_class, :count).by(1)
    end

    it "has timestamps after save" do
      chat.save!
      expect(chat.created_at).not_to be_nil
      expect(chat.updated_at).not_to be_nil
    end
  end
end
