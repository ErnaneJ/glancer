# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Indexer::ContextIndexer do
  let(:context_path) { "/fake/config/context.md" }
  let(:context_content) do
    <<~MD
      # Domain Context
      This application manages e-commerce orders and customers.

      ## Users
      Users have email, name, and created_at attributes.

      ## Orders
      Orders belong to users and have a total and status.
    MD
  end

  before do
    Glancer.configuration.context_file_path = context_path
    allow(File).to receive(:exist?).with(context_path).and_return(true)
    allow(File).to receive(:read).with(context_path).and_return(context_content)
  end

  # ── index! ────────────────────────────────────────────────────────────────

  describe ".index!" do
    it "returns an array of chunk hashes" do
      result = described_class.index!
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "sets source_type to 'context' on all chunks" do
      result = described_class.index!
      expect(result.map { |c| c[:source_type] }).to all(eq("context"))
    end

    it "sets source_path to the configured context_file_path" do
      result = described_class.index!
      expect(result.map { |c| c[:source_path] }).to all(eq(context_path))
    end

    it "includes the content from the context file" do
      result   = described_class.index!
      combined = result.map { |c| c[:content] }.join
      expect(combined).to include("Domain Context")
    end

    it "returns [] when the file starts with --glancer-ignore" do
      allow(File).to receive(:read).with(context_path).and_return("--glancer-ignore\nsome content")
      expect(described_class.index!).to eq([])
    end

    it "raises Glancer::Error when the file does not exist" do
      allow(File).to receive(:exist?).with(context_path).and_return(false)
      expect { described_class.index! }.to raise_error(Glancer::Error, /Context file not found/)
    end

    it "raises Glancer::Error when context_file_path is nil" do
      Glancer.configuration.context_file_path = "non_existent_file.md"
      allow(File).to receive(:exist?).and_return(false)
      expect { described_class.index! }.to raise_error(Glancer::Error)
    end

    it "raises Glancer::Error when File.read raises" do
      allow(File).to receive(:read).and_raise(IOError, "unreadable file")
      expect { described_class.index! }.to raise_error(Glancer::Error, /Context indexing failed/)
    end
  end

  # ── split_into_chunks ─────────────────────────────────────────────────────

  describe ".split_into_chunks" do
    before do
      Glancer.configuration.chunk_size    = 100
      Glancer.configuration.chunk_overlap = 10
    end

    it "returns one chunk for text shorter than chunk_size" do
      result = described_class.split_into_chunks("short")
      expect(result.size).to eq(1)
    end

    it "splits long text into multiple chunks" do
      result = described_class.split_into_chunks("x" * 300)
      expect(result.size).to be > 1
    end

    it "produces chunks of at most chunk_size characters" do
      result = described_class.split_into_chunks("y" * 300)
      result.each { |chunk| expect(chunk.length).to be <= 100 }
    end
  end
end
