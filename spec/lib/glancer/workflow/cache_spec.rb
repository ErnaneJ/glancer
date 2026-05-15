# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::Cache do
  let(:question) { "How many users are there?" }
  let(:result)   { { question: question, content: "42 users", sql: "SELECT COUNT(*) FROM users", successful: true } }

  before { described_class.clear }

  describe ".fetch" do
    context "when the cache is empty" do
      it "returns nil for an unknown question" do
        expect(described_class.fetch(question)).to be_nil
      end
    end

    context "when the cache has a fresh entry" do
      before { described_class.write(question, result) }

      it "returns the cached entry" do
        entry = described_class.fetch(question)
        expect(entry).not_to be_nil
        expect(entry[:content]).to eq("42 users")
      end

      it "includes the cached_at timestamp" do
        entry = described_class.fetch(question)
        expect(entry[:cached_at]).to be_a(Time)
      end
    end

    context "when the cache entry is expired" do
      before do
        described_class.write(question, result)
      end

      it "returns nil and removes the expired entry" do
        Glancer.configuration.workflow_cache_ttl = 1 # 1 second TTL
        # Simulate time passing beyond TTL
        old_time = Time.now - 10
        allow(Time).to receive(:current).and_return(old_time + 2)

        # Write with 'old' cached_at by manipulating after the fact
        described_class.clear
        described_class.write(question, result)
        # Now override Time.current to be far in the future
        allow(Time).to receive(:current).and_return(Time.now + 3600)

        expect(described_class.fetch(question)).to be_nil
      end
    end
  end

  describe ".write" do
    it "stores the result merged with cached_at" do
      described_class.write(question, result)
      entry = described_class.fetch(question)
      expect(entry).not_to be_nil
      expect(entry[:cached_at]).to be_a(Time)
      expect(entry[:sql]).to eq("SELECT COUNT(*) FROM users")
    end

    it "overwrites an existing entry for the same question" do
      described_class.write(question, result)
      new_result = result.merge(content: "Updated content")
      described_class.write(question, new_result)
      entry = described_class.fetch(question)
      expect(entry[:content]).to eq("Updated content")
    end
  end

  describe ".clear" do
    it "removes all cached entries" do
      described_class.write(question, result)
      described_class.write("another question", result)
      described_class.clear
      expect(described_class.fetch(question)).to be_nil
      expect(described_class.fetch("another question")).to be_nil
    end
  end

  # ── rescue paths ─────────────────────────────────────────────────────────

  describe "rescue paths" do
    it "fetch returns nil when an internal error occurs (e.g. expired? raises)" do
      described_class.write(question, result)
      allow(described_class).to receive(:expired?).and_raise(RuntimeError, "unexpected")
      expect(described_class.fetch(question)).to be_nil
    end

    it "write handles errors gracefully without raising" do
      store_mock = double("store")
      allow(store_mock).to receive(:[]=).and_raise(StandardError, "write error")
      allow(store_mock).to receive(:clear)
      allow(store_mock).to receive(:[]).and_return(nil)
      Glancer::Workflow::Cache.class_variable_set(:@@store, store_mock)
      allow(Glancer::Utils::Logger).to receive(:error)
      allow(Glancer::Utils::Logger).to receive(:debug)
      expect { described_class.write(question, result) }.not_to raise_error
    ensure
      Glancer::Workflow::Cache.class_variable_set(:@@store, {})
    end

    it "clear handles unexpected errors gracefully" do
      store_mock = double("store")
      allow(store_mock).to receive(:clear).and_raise(StandardError, "cannot clear")
      Glancer::Workflow::Cache.class_variable_set(:@@store, store_mock)
      allow(Glancer::Utils::Logger).to receive(:error)
      allow(Glancer::Utils::Logger).to receive(:debug)
      expect { described_class.clear }.not_to raise_error
    ensure
      Glancer::Workflow::Cache.class_variable_set(:@@store, {})
    end
  end

  describe ".expired?" do
    context "with a fresh entry" do
      it "returns false" do
        entry = { cached_at: Time.now }
        allow(Time).to receive(:current).and_return(Time.now)
        Glancer.configuration.workflow_cache_ttl = 300
        expect(described_class.expired?(entry)).to be(false)
      end
    end

    context "with an old entry beyond TTL" do
      it "returns true" do
        Glancer.configuration.workflow_cache_ttl = 1
        entry = { cached_at: Time.now - 60 }
        expect(described_class.expired?(entry)).to be(true)
      end
    end

    context "when entry has no cached_at" do
      it "returns true (safe default)" do
        entry = {}
        expect(described_class.expired?(entry)).to be(true)
      end
    end
  end
end
