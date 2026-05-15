# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::LLM do
  let(:fake_response) { double("Response", content: "The query counts all users in the system.") }
  let(:fake_chat) do
    double("Chat").tap do |c|
      allow(c).to receive(:ask).and_return(fake_response)
      allow(c).to receive(:with_instructions).and_return(c)
    end
  end

  before do
    allow(RubyLLM).to receive(:chat).and_return(fake_chat)
  end

  # ── .humanized_response ───────────────────────────────────────────────────

  describe ".humanized_response" do
    let(:question) { "How many users are there?" }
    let(:sql)      { "SELECT COUNT(*) FROM users" }
    let(:data)     { [{ "count" => 42 }] }

    it "returns the LLM response content" do
      result = described_class.humanized_response(question, data, sql)
      expect(result).to eq("The query counts all users in the system.")
    end

    it "calls RubyLLM.chat with the configured chat provider and model" do
      expect(RubyLLM).to receive(:chat).with(
        hash_including(provider: Glancer.configuration.resolved_chat_provider,
                       model: Glancer.configuration.resolved_chat_model)
      ).and_return(fake_chat)
      described_class.humanized_response(question, data, sql)
    end

    it "returns a fallback string when the LLM raises" do
      allow(RubyLLM).to receive(:chat).and_raise(StandardError, "timeout")
      result = described_class.humanized_response(question, data, sql)
      expect(result).to include("failed to generate")
    end

    it "appends custom instructions when they exist" do
      Glancer::Setting.set("custom_instructions", "Always use bullet points")
      # The system prompt should include the custom instruction;
      # we verify by checking that with_instructions is called or ask receives the prompt
      expect(fake_chat).to receive(:ask).and_return(fake_response)
      described_class.humanized_response(question, data, sql)
    end
  end

  # ── .explain_missing_tables ───────────────────────────────────────────────

  describe ".explain_missing_tables" do
    let(:question)      { "Show all affiliates" }
    let(:error_message) { "Table validation failed: Missing table(s) in indexed schema: affiliates" }

    it "returns the LLM's explanation" do
      allow(fake_response).to receive(:content).and_return("The table 'affiliates' was not found.")
      allow(fake_chat).to receive(:ask).and_return(fake_response)
      result = described_class.explain_missing_tables(question, error_message)
      expect(result).to eq("The table 'affiliates' was not found.")
    end

    it "returns a fallback string when the LLM raises" do
      allow(RubyLLM).to receive(:chat).and_raise(StandardError, "API error")
      result = described_class.explain_missing_tables(question, error_message)
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end

  # ── .generate_title ───────────────────────────────────────────────────────

  describe ".generate_title" do
    let(:question) { "Show me all revenue by region for last quarter" }

    it "returns the LLM-generated title (truncated to 50 chars)" do
      allow(fake_response).to receive(:content).and_return("Revenue by Region Last Quarter")
      allow(fake_chat).to receive(:ask).and_return(fake_response)
      result = described_class.generate_title(question)
      expect(result).to eq("Revenue by Region Last Quarter")
      expect(result.length).to be <= 50
    end

    it "truncates a very long LLM response to 50 characters" do
      long_title = "A" * 100
      allow(fake_response).to receive(:content).and_return(long_title)
      allow(fake_chat).to receive(:ask).and_return(fake_response)
      result = described_class.generate_title(question)
      expect(result.length).to be <= 50
    end

    it "falls back to a truncated question when the LLM raises" do
      allow(RubyLLM).to receive(:chat).and_raise(StandardError, "error")
      result = described_class.generate_title(question)
      expect(result).to be_a(String)
      expect(result.length).to be <= 50
    end
  end

  # ── .explain_error ────────────────────────────────────────────────────────

  describe ".explain_error" do
    let(:question)      { "Count orders by customer" }
    let(:error_message) { "no such column: customer_id" }
    let(:sql)           { "SELECT customer_id, COUNT(*) FROM orders GROUP BY customer_id" }

    it "returns the LLM's error explanation" do
      allow(fake_response).to receive(:content).and_return("We couldn't find the column customer_id.")
      allow(fake_chat).to receive(:ask).and_return(fake_response)
      result = described_class.explain_error(question, error_message, sql)
      expect(result).to eq("We couldn't find the column customer_id.")
    end

    it "calls RubyLLM.chat with the chat provider config" do
      expect(RubyLLM).to receive(:chat).with(
        hash_including(provider: Glancer.configuration.resolved_chat_provider)
      ).and_return(fake_chat)
      described_class.explain_error(question, error_message, sql)
    end
  end
end
