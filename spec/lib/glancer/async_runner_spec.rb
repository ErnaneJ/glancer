# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::AsyncRunner do
  let(:chat)    { Glancer::Chat.create!(title: "Test") }
  let(:message) do
    Glancer::Message.create!(
      chat: chat, role: :assistant, content: "", code_type: "sql", status: :processing
    )
  end
  let(:question) { "How many users?" }

  let(:workflow_result) do
    {
      content: "There are 5 users.",
      code: "SELECT COUNT(*) FROM users",
      code_type: "sql",
      successful: true,
      enriched_question: nil
    }
  end

  before do
    allow(Glancer::Workflow).to receive(:run).and_return(workflow_result)
    allow(Glancer::Workflow::LLM).to receive(:generate_title).and_return("User count")
    # Stub resolved_chat_provider/model so the model string builds without config errors
    allow(Glancer.configuration).to receive(:resolved_chat_provider).and_return("gemini")
    allow(Glancer.configuration).to receive(:resolved_chat_model).and_return("gemini-2.0-flash")
  end

  # ── .run ──────────────────────────────────────────────────────────────────

  describe ".run" do
    it "updates the message status to :processing then :complete" do
      described_class.run(message.id, question)
      expect(message.reload.status).to eq("complete")
    end

    it "stores the workflow content on the message" do
      described_class.run(message.id, question)
      expect(message.reload.content).to eq("There are 5 users.")
    end

    it "stores the generated code on the message" do
      described_class.run(message.id, question)
      expect(message.reload.code).to eq("SELECT COUNT(*) FROM users")
    end

    it "marks the message as successful" do
      described_class.run(message.id, question)
      expect(message.reload.successful).to be(true)
    end

    it "creates a code_version record for the generated code" do
      expect { described_class.run(message.id, question) }
        .to change(Glancer::CodeVersion, :count).by(1)
    end

    it "does not create a code_version when the result has no code" do
      allow(Glancer::Workflow).to receive(:run).and_return(workflow_result.merge(code: nil))
      expect { described_class.run(message.id, question) }
        .not_to change(Glancer::CodeVersion, :count)
    end

    it "updates the chat title on the first user message" do
      chat.messages.create!(role: :user, content: question)
      described_class.run(message.id, question)
      expect(chat.reload.title).to eq("User count")
    end

    it "does not update the chat title when multiple user messages exist" do
      2.times { chat.messages.create!(role: :user, content: question) }
      expect(Glancer::Workflow::LLM).not_to receive(:generate_title)
      described_class.run(message.id, question)
    end

    context "when the workflow raises" do
      before { allow(Glancer::Workflow).to receive(:run).and_raise(StandardError, "LLM down") }

      it "marks the message as failed" do
        described_class.run(message.id, question)
        expect(message.reload.status).to eq("failed")
      end

      it "stores the error message as content" do
        described_class.run(message.id, question)
        expect(message.reload.content).to eq("LLM down")
      end

      it "marks the message as not successful" do
        described_class.run(message.id, question)
        expect(message.reload.successful).to be(false)
      end
    end

    context "when both workflow and the rescue update raise" do
      before do
        allow(Glancer::Workflow).to receive(:run).and_raise(StandardError, "boom")
        allow_any_instance_of(Glancer::Message).to receive(:update!).and_call_original
        allow_any_instance_of(Glancer::Message).to receive(:update!)
          .with(hash_including(status: :failed))
          .and_raise(StandardError, "db gone")
      end

      it "does not propagate the secondary error" do
        expect { described_class.run(message.id, question) }.not_to raise_error
      end
    end
  end

  # ── .call ─────────────────────────────────────────────────────────────────

  describe ".call" do
    it "returns a Thread" do
      t = described_class.call(message.id, question)
      t.join
      expect(t).to be_a(Thread)
    end

    it "executes .run inside the thread" do
      expect(described_class).to receive(:run).with(message.id, question)
      described_class.call(message.id, question).join
    end

    it "does not raise when the thread encounters an error outside with_connection" do
      msg_id = message.id # force lazy let evaluation before stubbing connection_pool
      allow(ActiveRecord::Base).to receive(:connection_pool)
        .and_raise(StandardError, "pool error")
      expect { described_class.call(msg_id, question).join }.not_to raise_error
    end
  end
end
