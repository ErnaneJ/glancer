# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Retriever do
  let(:fake_embed_response) { double("EmbedResponse", vectors: [0.1, 0.2, 0.3]) }

  before do
    allow(RubyLLM).to receive(:embed).and_return(fake_embed_response)
  end

  # ── store_documents ───────────────────────────────────────────────────────

  describe ".store_documents" do
    let(:chunks) do
      [
        { content: "create_table users ...", source_type: "schema", source_path: "db/schema.rb#users" },
        { content: "class User < ApplicationRecord", source_type: "models", source_path: "app/models/user.rb" }
      ]
    end

    it "creates an Embedding record for each chunk" do
      expect { described_class.store_documents(chunks) }.to change(Glancer::Embedding, :count).by(2)
    end

    it "stores the content from each chunk" do
      described_class.store_documents(chunks)
      contents = Glancer::Embedding.pluck(:content)
      expect(contents).to include("create_table users ...", "class User < ApplicationRecord")
    end

    it "stores the source_type from each chunk" do
      described_class.store_documents(chunks)
      types = Glancer::Embedding.pluck(:source_type)
      expect(types).to include("schema", "models")
    end

    it "stores the source_path from each chunk" do
      described_class.store_documents(chunks)
      paths = Glancer::Embedding.pluck(:source_path)
      expect(paths).to include("db/schema.rb#users", "app/models/user.rb")
    end

    it "stores the embedding vector returned by RubyLLM.embed" do
      described_class.store_documents([chunks.first])
      emb = Glancer::Embedding.last
      expect(emb.embedding.map(&:to_f)).to eq([0.1, 0.2, 0.3])
    end

    it "calls RubyLLM.embed once per chunk" do
      expect(RubyLLM).to receive(:embed).exactly(2).times.and_return(fake_embed_response)
      described_class.store_documents(chunks)
    end

    it "raises Glancer::Error when RubyLLM.embed fails" do
      allow(RubyLLM).to receive(:embed).and_raise(StandardError, "API down")
      expect { described_class.store_documents(chunks) }.to raise_error(Glancer::Error, /Document storage failed/)
    end
  end

  # ── search ────────────────────────────────────────────────────────────────

  describe ".search" do
    before do
      Glancer::Embedding.create!(
        content: "create_table users ...", embedding: [0.1, 0.2, 0.3],
        source_type: "schema", source_path: "db/schema.rb#users"
      )
    end

    it "returns an array of Embedding records" do
      results = described_class.search("count users")
      expect(results).to all(be_a(Glancer::Embedding))
    end

    it "attaches a score singleton method to each result" do
      results = described_class.search("something")
      expect(results.first).to respond_to(:score)
    end

    it "calls RubyLLM.embed with the query" do
      expect(RubyLLM).to receive(:embed).with("find users", anything).and_return(fake_embed_response)
      described_class.search("find users")
    end
  end

  # ── perform_ruby_search ───────────────────────────────────────────────────

  describe ".perform_ruby_search" do
    before do
      Glancer::Embedding.create!(
        content: "schema doc", embedding: [1.0, 0.0, 0.0],
        source_type: "schema", source_path: "schema.rb#t"
      )
      Glancer::Embedding.create!(
        content: "model doc", embedding: [0.0, 1.0, 0.0],
        source_type: "models", source_path: "user.rb"
      )
    end

    it "returns results filtered by min_score" do
      Glancer.configuration.min_score = 0.99
      results = described_class.perform_ruby_search([1.0, 0.0, 0.0])
      expect(results.size).to eq(1)
    end

    it "limits results to k embeddings" do
      Glancer.configuration.k = 1
      Glancer.configuration.min_score = 0.0
      results = described_class.perform_ruby_search([1.0, 0.0, 0.0])
      expect(results.size).to eq(1)
    end

    it "applies schema weight (1.3) to schema embeddings" do
      Glancer.configuration.min_score = 0.0
      results = described_class.perform_ruby_search([1.0, 0.0, 0.0])
      schema_result = results.find { |r| r.source_type == "schema" }
      # Score for a perfect match should be ~1.3 (1.0 cosine * 1.3 weight)
      expect(schema_result.score).to be_within(0.01).of(1.3)
    end
  end

  # ── cosine_similarity ─────────────────────────────────────────────────────

  describe ".cosine_similarity" do
    it "returns 1.0 for identical vectors" do
      vec = [1.0, 2.0, 3.0]
      expect(described_class.cosine_similarity(vec, vec)).to be_within(1e-9).of(1.0)
    end

    it "returns 0.0 for orthogonal vectors" do
      expect(described_class.cosine_similarity([1.0, 0.0], [0.0, 1.0])).to eq(0.0)
    end

    it "returns 0.0 when the first vector is all zeros" do
      expect(described_class.cosine_similarity([0.0, 0.0], [1.0, 2.0])).to eq(0.0)
    end

    it "returns 0.0 when the second vector is all zeros" do
      expect(described_class.cosine_similarity([1.0, 2.0], [0.0, 0.0])).to eq(0.0)
    end

    it "is symmetric" do
      a = [0.3, 0.7, 0.1]
      b = [0.5, 0.2, 0.8]
      expect(described_class.cosine_similarity(a, b)).to eq(described_class.cosine_similarity(b, a))
    end
  end

  # ── weight_for ────────────────────────────────────────────────────────────

  describe ".weight_for" do
    it "returns schema_documents_weight for 'schema'" do
      Glancer.configuration.schema_documents_weight = 1.3
      expect(described_class.weight_for("schema")).to eq(1.3)
    end

    it "returns context_documents_weight for 'context'" do
      Glancer.configuration.context_documents_weight = 1.2
      expect(described_class.weight_for("context")).to eq(1.2)
    end

    it "returns models_documents_weight for 'models'" do
      Glancer.configuration.models_documents_weight = 1.1
      expect(described_class.weight_for("models")).to eq(1.1)
    end

    it "returns 1.0 for any other source type" do
      expect(described_class.weight_for("unknown")).to eq(1.0)
    end
  end
end
