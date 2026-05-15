# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Indexer do
  let(:schema_chunk)  { { content: "create_table users", source_type: "schema", source_path: "db/schema.rb#users" } }
  let(:model_chunk)   { { content: "class User",         source_type: "models", source_path: "app/models/user.rb" } }
  let(:context_chunk) { { content: "# Context",          source_type: "context", source_path: "config/context.md" } }

  before do
    allow(Glancer::Retriever).to receive(:store_documents)
    allow(Glancer::Indexer::SchemaIndexer).to receive(:index!).and_return([schema_chunk])
    allow(Glancer::Indexer::ModelIndexer).to receive(:index!).and_return([model_chunk])
    allow(Glancer::Indexer::ContextIndexer).to receive(:index!).and_return([context_chunk])
  end

  describe ".rebuild_all!" do
    context "when schema_permission is false (default)" do
      it "does not call SchemaIndexer.index!" do
        expect(Glancer::Indexer::SchemaIndexer).not_to receive(:index!)
        described_class.rebuild_all!
      end
    end

    context "when schema_permission is true" do
      before { Glancer.configuration.schema_permission = true }

      it "calls SchemaIndexer.index!" do
        expect(Glancer::Indexer::SchemaIndexer).to receive(:index!).and_return([schema_chunk])
        described_class.rebuild_all!
      end

      it "includes schema chunks in the result" do
        chunks = described_class.rebuild_all!
        expect(chunks).to include(schema_chunk)
      end
    end

    context "when models_permission is false (default)" do
      it "does not call ModelIndexer.index!" do
        expect(Glancer::Indexer::ModelIndexer).not_to receive(:index!)
        described_class.rebuild_all!
      end
    end

    context "when models_permission is true" do
      before { Glancer.configuration.models_permission = true }

      it "calls ModelIndexer.index!" do
        expect(Glancer::Indexer::ModelIndexer).to receive(:index!).and_return([model_chunk])
        described_class.rebuild_all!
      end
    end

    context "when context_file_path is set (default is set)" do
      it "calls ContextIndexer.index!" do
        expect(Glancer::Indexer::ContextIndexer).to receive(:index!).and_return([context_chunk])
        described_class.rebuild_all!
      end

      it "includes context chunks in the result" do
        chunks = described_class.rebuild_all!
        expect(chunks).to include(context_chunk)
      end
    end

    context "when context_file_path is nil" do
      before { allow(Glancer.configuration).to receive(:context_file_path).and_return(nil) }

      it "skips ContextIndexer.index!" do
        expect(Glancer::Indexer::ContextIndexer).not_to receive(:index!)
        described_class.rebuild_all!
      end
    end

    it "calls Retriever.store_documents with accumulated chunks" do
      Glancer.configuration.schema_permission = true
      Glancer.configuration.models_permission = true
      expect(Glancer::Retriever).to receive(:store_documents).with(array_including(schema_chunk, model_chunk, context_chunk))
      described_class.rebuild_all!
    end

    it "returns the combined chunks array" do
      Glancer.configuration.schema_permission = true
      Glancer.configuration.models_permission = true
      chunks = described_class.rebuild_all!
      expect(chunks).to be_an(Array)
    end

    it "raises Glancer::Error when an indexer raises" do
      allow(Glancer::Indexer::ContextIndexer).to receive(:index!).and_raise(StandardError, "disk error")
      expect { described_class.rebuild_all! }.to raise_error(Glancer::Error, /Index rebuilding failed/)
    end
  end
end
