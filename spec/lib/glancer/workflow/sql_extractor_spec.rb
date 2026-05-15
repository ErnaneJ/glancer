# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::SQLExtractor do
  describe ".extract" do
    context "when the text contains a ```sql ... ``` code block" do
      it "extracts the SQL from a fenced sql block" do
        text = "Here is the query:\n```sql\nSELECT * FROM users\n```"
        expect(described_class.extract(text)).to eq("SELECT * FROM users")
      end

      it "handles multi-line SQL inside the block" do
        text = "```sql\nSELECT id, name\nFROM users\nWHERE active = 1\n```"
        result = described_class.extract(text)
        expect(result).to include("SELECT id, name")
        expect(result).to include("FROM users")
        expect(result).to include("WHERE active = 1")
      end

      it "handles SQL blocks with uppercase SQL language hint" do
        text = "```SQL\nSELECT 1\n```"
        expect(described_class.extract(text)).to eq("SELECT 1")
      end

      it "strips surrounding whitespace from the extracted SQL" do
        text = "```sql\n  SELECT 1  \n```"
        expect(described_class.extract(text)).to eq("SELECT 1")
      end
    end

    context "when the text contains a plain ``` ... ``` block without a language hint" do
      it "extracts the SQL from a plain fenced block" do
        text = "Result:\n```\nSELECT 1\n```"
        expect(described_class.extract(text)).to eq("SELECT 1")
      end
    end

    context "when there is no code block but a SELECT keyword exists" do
      it "finds the SELECT line and takes everything from there" do
        text = "Sure, I can help.\nSELECT * FROM orders\nWHERE id = 1"
        result = described_class.extract(text)
        expect(result).to start_with("SELECT * FROM orders")
      end

      it "detects a WITH (CTE) keyword as SQL start" do
        text = "Here's a CTE:\nWITH cte AS (SELECT 1) SELECT * FROM cte"
        result = described_class.extract(text)
        expect(result).to start_with("WITH cte AS")
      end

      it "detects EXPLAIN keyword as SQL start" do
        text = "Explanation:\nEXPLAIN SELECT * FROM users"
        result = described_class.extract(text)
        expect(result).to start_with("EXPLAIN SELECT")
      end

      it "is case-insensitive for the SQL start pattern" do
        text = "some text\nselect * from t"
        result = described_class.extract(text)
        expect(result).to include("select * from t")
      end
    end

    context "when no SQL can be found" do
      it "returns the raw text joined into a single line (raw join fallback)" do
        text = "I cannot generate a query for this request."
        result = described_class.extract(text)
        expect(result).to include("I cannot generate")
      end
    end

    context "error handling" do
      it "raises Glancer::Error when an unexpected exception occurs" do
        allow(described_class).to receive(:extract).and_call_original
        bad_text = double("bad text")
        allow(bad_text).to receive(:=~).and_raise(RuntimeError, "unexpected")
        expect { described_class.extract(bad_text) }.to raise_error(Glancer::Error, /SQL extraction failed/)
      end
    end
  end
end
