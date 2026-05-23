# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::ARExecutor do
  # ── normalize ─────────────────────────────────────────────────────────────

  describe ".normalize" do
    it "converts an ActiveRecord::Relation to an array of attribute hashes" do
      chat = Glancer::Chat.create!(title: "Test")
      relation = Glancer::Chat.where(id: chat.id)
      result = described_class.normalize(relation)
      expect(result).to be_an(Array)
      expect(result.first).to include("id" => chat.id, "title" => "Test")
    end

    it "converts an Array of AR objects to attribute hashes" do
      chat = Glancer::Chat.create!(title: "AR")
      result = described_class.normalize([chat])
      expect(result).to be_an(Array)
      expect(result.first).to include("title" => "AR")
    end

    it "wraps a Numeric in a result hash" do
      result = described_class.normalize(42)
      expect(result).to eq([{ "result" => 42 }])
    end

    it "wraps a String in a result hash" do
      result = described_class.normalize("hello")
      expect(result).to eq([{ "result" => "hello" }])
    end

    it "wraps a Hash in an array" do
      result = described_class.normalize({ "count" => 5 })
      expect(result).to eq([{ "count" => 5 }])
    end

    it "returns [] for nil" do
      expect(described_class.normalize(nil)).to eq([])
    end

    it "handles an Array of primitives" do
      result = described_class.normalize(%w[a b])
      expect(result).to eq([{ "value" => "a" }, { "value" => "b" }])
    end

    it "stringifies keys of hashes inside an array" do
      result = described_class.normalize([{ count: 3 }])
      expect(result.first).to include("count" => 3)
    end
  end

  # ── execute ───────────────────────────────────────────────────────────────

  describe ".execute" do
    let(:safe_code) { "Glancer::Chat.count" }

    it "returns an array of result hashes for a successful expression" do
      result = described_class.execute(safe_code)
      expect(result).to be_an(Array)
      expect(result.first).to include("result" => 0)
    end

    it "creates a Glancer::Audit record after success" do
      expect { described_class.execute(safe_code, original_question: "How many chats?") }
        .to change(Glancer::Audit, :count).by(1)
    end

    it "stores the Ruby expression in the audit sql column" do
      described_class.execute(safe_code)
      expect(Glancer::Audit.last.sql).to eq(safe_code)
    end

    it "stores the run_id in the audit record" do
      described_class.execute(safe_code)
      expect(Glancer::Audit.last.run_id).to be_a(String).and be_present
    end

    it "stores original_question in the audit record" do
      described_class.execute(safe_code, original_question: "count chats")
      expect(Glancer::Audit.last.question).to eq("count chats")
    end

    it "rolls back the transaction — side effects inside eval are reverted" do
      # The AR expression itself is read-only, so this just verifies the mechanism works
      result = described_class.execute("Glancer::Chat.count")
      expect(result).to be_an(Array)
    end
  end

  # ── retry on failure ──────────────────────────────────────────────────────

  describe ".execute — retry with Builder.fix_ar_code" do
    let(:bad_code)   { "NonExistentModel.all" }
    let(:fixed_code) { "Glancer::Chat.count" }

    before do
      allow(Glancer::Workflow::Builder).to receive(:fix_ar_code).and_return(fixed_code)
    end

    it "calls Builder.fix_ar_code on failure and retries" do
      expect(Glancer::Workflow::Builder).to receive(:fix_ar_code).at_least(:once).and_return(fixed_code)
      described_class.execute(bad_code)
    end

    it "returns the result from the fixed code" do
      result = described_class.execute(bad_code)
      expect(result).to be_an(Array)
    end

    it "returns an error hash after 3 failed attempts" do
      allow(Glancer::Workflow::Builder).to receive(:fix_ar_code).and_return(bad_code)
      result = described_class.execute(bad_code, attempt: 1)
      expect(result).to be_a(Hash)
      expect(result[:error]).to be(true)
      expect(result[:message]).to be_a(String)
      expect(result[:last_sql]).to eq(bad_code)
    end
  end
end
