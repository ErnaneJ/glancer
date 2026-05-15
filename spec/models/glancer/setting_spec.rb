# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Setting do
  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it "is valid with a unique key" do
      setting = described_class.new(key: "some_key", value: "val")
      expect(setting).to be_valid
    end

    it "is invalid without a key" do
      setting = described_class.new(key: nil, value: "val")
      expect(setting).not_to be_valid
    end

    it "enforces key uniqueness" do
      described_class.create!(key: "duplicate", value: "first")
      dup = described_class.new(key: "duplicate", value: "second")
      expect(dup).not_to be_valid
      expect(dup.errors[:key]).to be_present
    end
  end

  # ── .get ──────────────────────────────────────────────────────────────────

  describe ".get" do
    it "returns the value for an existing key" do
      described_class.create!(key: "my_key", value: "hello")
      expect(described_class.get("my_key")).to eq("hello")
    end

    it "returns the default when the key does not exist" do
      expect(described_class.get("missing", default: "fallback")).to eq("fallback")
    end

    it "returns nil by default when key is missing and no default given" do
      expect(described_class.get("nonexistent")).to be_nil
    end

    it "accepts symbol keys" do
      described_class.create!(key: "sym_key", value: "sym_val")
      expect(described_class.get(:sym_key)).to eq("sym_val")
    end
  end

  # ── .set ──────────────────────────────────────────────────────────────────

  describe ".set" do
    it "creates a new setting record" do
      expect { described_class.set("brand_new", "value") }.to change(described_class, :count).by(1)
    end

    it "updates an existing record instead of creating a duplicate" do
      described_class.set("existing", "old")
      expect { described_class.set("existing", "new") }.not_to change(described_class, :count)
      expect(described_class.get("existing")).to eq("new")
    end

    it "converts the value to a String" do
      described_class.set("numeric_key", 42)
      expect(described_class.get("numeric_key")).to eq("42")
    end

    it "converts the key to a String" do
      described_class.set(:symbol_key, "v")
      expect(described_class.get("symbol_key")).to eq("v")
    end
  end

  # ── .store_many ───────────────────────────────────────────────────────────

  describe ".store_many" do
    it "stores all key-value pairs in the hash" do
      described_class.store_many(foo: "bar", baz: "qux")
      expect(described_class.get(:foo)).to eq("bar")
      expect(described_class.get(:baz)).to eq("qux")
    end

    it "updates existing keys" do
      described_class.set("k", "original")
      described_class.store_many(k: "updated")
      expect(described_class.get("k")).to eq("updated")
    end
  end
end
