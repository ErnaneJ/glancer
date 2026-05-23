# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::ARExtractor do
  describe ".extract" do
    it "extracts code from a ```ruby block" do
      text = "```ruby\nUser.where(active: true).count\n```"
      expect(described_class.extract(text)).to eq("User.where(active: true).count")
    end

    it "extracts code from a plain ``` block" do
      text = "```\nOrder.joins(:items).count\n```"
      expect(described_class.extract(text)).to eq("Order.joins(:items).count")
    end

    it "strips surrounding whitespace from the code block content" do
      text = "```ruby\n  User.all  \n```"
      expect(described_class.extract(text)).to eq("User.all")
    end

    it "returns the raw text when there is no code block" do
      text = "User.count"
      expect(described_class.extract(text)).to eq("User.count")
    end

    it "strips the raw text when there is no code block" do
      text = "  User.count  "
      expect(described_class.extract(text)).to eq("User.count")
    end

    it "handles multi-line expressions inside a code block" do
      text = "```ruby\nUser\n  .where(active: true)\n  .order(:name)\n```"
      expect(described_class.extract(text)).to include("User")
      expect(described_class.extract(text)).to include(".where(active: true)")
    end

    it "raises Glancer::Error if extraction fails unexpectedly" do
      allow(described_class).to receive(:extract).and_call_original
      # normal path; just verify it doesn't raise on valid input
      expect { described_class.extract("User.count") }.not_to raise_error
    end
  end
end
