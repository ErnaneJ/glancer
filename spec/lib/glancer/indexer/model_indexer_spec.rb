# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Indexer::ModelIndexer do
  let(:fake_root) { Pathname.new("/fake/app") }
  let(:model_content) do
    <<~RUBY
      class User < ApplicationRecord
        has_many :orders
        validates :email, presence: true
      end
    RUBY
  end
  let(:model_file) { "/fake/app/app/models/user.rb" }

  before do
    allow(Rails).to receive(:root).and_return(fake_root)
    allow(Dir).to receive(:[]).with(fake_root.join("app/models/**/*.rb")).and_return([model_file])
    allow(File).to receive(:read).with(model_file).and_return(model_content)
  end

  # ── index! ────────────────────────────────────────────────────────────────

  describe ".index!" do
    it "returns an array of chunk hashes" do
      result = described_class.index!
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "sets source_type to 'models' on all chunks" do
      result = described_class.index!
      expect(result.map { |c| c[:source_type] }).to all(eq("models"))
    end

    it "sets source_path to the file path" do
      result = described_class.index!
      expect(result.map { |c| c[:source_path] }).to all(eq(model_file))
    end

    it "includes the content of the model file" do
      result = described_class.index!
      combined = result.map { |c| c[:content] }.join
      expect(combined).to include("class User")
    end

    it "returns [] when no model files are found" do
      allow(Dir).to receive(:[]).and_return([])
      expect(described_class.index!).to eq([])
    end

    it "handles multiple model files" do
      second_file    = "/fake/app/app/models/order.rb"
      second_content = "class Order < ApplicationRecord; end"
      allow(Dir).to receive(:[]).and_return([model_file, second_file])
      allow(File).to receive(:read).with(second_file).and_return(second_content)

      result = described_class.index!
      paths  = result.map { |c| c[:source_path] }.uniq
      expect(paths).to include(model_file, second_file)
    end

    it "raises Glancer::Error when File.read raises" do
      allow(File).to receive(:read).and_raise(IOError, "unreadable")
      expect { described_class.index! }.to raise_error(Glancer::Error, /Model indexing failed/)
    end
  end

  # ── split_into_chunks ─────────────────────────────────────────────────────

  describe ".split_into_chunks" do
    before do
      Glancer.configuration.chunk_size    = 100
      Glancer.configuration.chunk_overlap = 20
    end

    it "returns at least one chunk for any non-empty text" do
      result = described_class.split_into_chunks("x" * 50)
      expect(result.size).to be >= 1
    end

    it "splits long text into multiple chunks" do
      long_text = "a" * 250
      result    = described_class.split_into_chunks(long_text)
      expect(result.size).to be > 1
    end

    it "respects chunk_size from configuration" do
      Glancer.configuration.chunk_size    = 200
      Glancer.configuration.chunk_overlap = 0 # no overlap so the text fits in exactly 1 chunk
      result = described_class.split_into_chunks("b" * 200)
      expect(result.size).to eq(1)
    end

    it "applies overlap so successive chunks share content" do
      text   = "a" * 180
      result = described_class.split_into_chunks(text)
      # With size=100 and overlap=20, second chunk starts at index 80
      expect(result[1]).to start_with("a" * 20)
    end
  end
end
