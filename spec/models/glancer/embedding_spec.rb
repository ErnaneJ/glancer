# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Embedding do
  # ── Persistence ───────────────────────────────────────────────────────────

  describe "persistence" do
    it "saves an embedding with an array of floats" do
      embedding = described_class.create!(
        content: "create_table users ...",
        embedding: [0.1, 0.2, 0.3],
        source_type: "schema",
        source_path: "/path/to/schema.rb#users"
      )
      expect(embedding).to be_persisted
    end

    it "retrieves the embedding array after save" do
      described_class.create!(
        content: "some content",
        embedding: [1.0, 2.0, 3.0]
      )
      loaded = described_class.last
      expect(loaded.embedding).to be_a(Array)
      expect(loaded.embedding.map(&:to_f)).to eq([1.0, 2.0, 3.0])
    end

    it "stores and retrieves an empty array" do
      described_class.create!(content: "empty", embedding: [])
      loaded = described_class.last
      expect(loaded.embedding).to eq([])
    end
  end

  # ── Serialisation ─────────────────────────────────────────────────────────

  describe "serialize :embedding, Array" do
    it "serialises the embedding to a storable format" do
      emb = described_class.new(content: "x", embedding: [0.5, 0.6])
      emb.save!
      raw = ActiveRecord::Base.connection
                              .exec_query("SELECT embedding FROM glancer_embeddings WHERE id = #{emb.id}")
                              .first["embedding"]
      # The serialised form should be a String (YAML or JSON)
      expect(raw).to be_a(String)
    end
  end

  # ── Scopes via where ──────────────────────────────────────────────────────

  describe "filtering by source_type" do
    before do
      described_class.create!(content: "schema chunk",  embedding: [], source_type: "schema",  source_path: "schema.rb#users")
      described_class.create!(content: "model chunk",   embedding: [], source_type: "models",  source_path: "user.rb")
      described_class.create!(content: "context chunk", embedding: [], source_type: "context", source_path: "context.md")
    end

    it "can filter schema embeddings" do
      schema_embeds = described_class.where(source_type: "schema")
      expect(schema_embeds.count).to eq(1)
      expect(schema_embeds.first.content).to include("schema chunk")
    end

    it "can filter model embeddings" do
      expect(described_class.where(source_type: "models").count).to eq(1)
    end

    it "can filter context embeddings" do
      expect(described_class.where(source_type: "context").count).to eq(1)
    end
  end
end
