# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Utils::ResultFormatter do
  describe ".normalize" do
    context "when rows is empty" do
      it "returns the empty array as-is" do
        expect(described_class.normalize([])).to eq([])
      end
    end

    context "when all rows have the same keys" do
      let(:rows) do
        [
          { "id" => 1, "name" => "Alice" },
          { "id" => 2, "name" => "Bob" },
          { "id" => 3, "name" => "Carol" }
        ]
      end

      it "pivots to a hash of key => [values...]" do
        result = described_class.normalize(rows)
        expect(result).to be_a(Hash)
        expect(result["id"]).to eq([1, 2, 3])
        expect(result["name"]).to eq(%w[Alice Bob Carol])
      end

      it "preserves all original keys" do
        result = described_class.normalize(rows)
        expect(result.keys).to contain_exactly("id", "name")
      end
    end

    context "when rows have different keys" do
      let(:rows) do
        [
          { "id" => 1, "name" => "Alice" },
          { "id" => 2, "email" => "bob@example.com" }
        ]
      end

      it "returns the rows array as-is" do
        result = described_class.normalize(rows)
        expect(result).to eq(rows)
      end
    end

    context "with a single-row result set" do
      let(:rows) { [{ "count" => 42 }] }

      it "pivots to { 'count' => [42] }" do
        result = described_class.normalize(rows)
        expect(result).to eq({ "count" => [42] })
      end
    end

    context "with symbol keys" do
      let(:rows) do
        [
          { id: 1, score: 9.5 },
          { id: 2, score: 7.3 }
        ]
      end

      it "pivots correctly using symbol keys" do
        result = described_class.normalize(rows)
        expect(result[:id]).to eq([1, 2])
        expect(result[:score]).to eq([9.5, 7.3])
      end
    end
  end
end
