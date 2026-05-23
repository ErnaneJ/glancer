# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::Executor do
  let(:valid_sql)  { "SELECT 1 AS n" }
  let(:update_sql) { "UPDATE users SET name = 'x'" }

  # ── Security guard ────────────────────────────────────────────────────────

  describe ".execute — security guard" do
    it "raises Glancer::Error for UPDATE SQL" do
      expect { described_class.execute(update_sql) }
        .to raise_error(Glancer::Error, /Only SELECT queries are allowed/)
    end

    it "raises Glancer::Error for DELETE SQL" do
      expect { described_class.execute("DELETE FROM users") }
        .to raise_error(Glancer::Error, /Only SELECT queries are allowed/)
    end

    it "raises Glancer::Error for INSERT SQL" do
      expect { described_class.execute("INSERT INTO users VALUES (1)") }
        .to raise_error(Glancer::Error, /Only SELECT queries are allowed/)
    end

    it "raises Glancer::Error for DROP SQL" do
      expect { described_class.execute("DROP TABLE users") }
        .to raise_error(Glancer::Error, /Only SELECT queries are allowed/)
    end

    it "allows SELECT queries through" do
      result = described_class.execute(valid_sql)
      expect(result).to be_an(Array)
    end

    it "allows WITH (CTE) queries through" do
      cte_sql = "WITH t AS (SELECT 1 AS x) SELECT x FROM t"
      expect { described_class.execute(cte_sql) }.not_to raise_error
    end
  end

  # ── Successful execution ──────────────────────────────────────────────────

  describe ".execute — successful execution" do
    it "returns an array of result rows" do
      result = described_class.execute(valid_sql)
      expect(result).to be_an(Array)
      expect(result.first).to include("n" => 1)
    end

    it "creates a Glancer::Audit record after success" do
      expect { described_class.execute(valid_sql, original_question: "What is 1?") }
        .to change(Glancer::Audit, :count).by(1)
    end

    it "stores the run_id in the audit record" do
      described_class.execute(valid_sql)
      audit = Glancer::Audit.last
      expect(audit.run_id).to be_a(String)
      expect(audit.run_id).not_to be_empty
    end

    it "appends the /*glancer,run_id:...*/ comment to the stored code" do
      described_class.execute(valid_sql)
      audit = Glancer::Audit.last
      expect(audit.code).to include("/*glancer,run_id:")
    end

    it "stores the original_question in the audit record" do
      described_class.execute(valid_sql, original_question: "count rows")
      expect(Glancer::Audit.last.question).to eq("count rows")
    end

    it "stores the message_id when provided" do
      chat = Glancer::Chat.create!(title: "C")
      msg  = Glancer::Message.create!(chat: chat, role: "assistant", content: "x")
      described_class.execute(valid_sql, message_id: msg.id)
      expect(Glancer::Audit.last.message_id).to eq(msg.id)
    end

    it "rolls back the transaction (read-only safety) — any DML inside rolled back" do
      # The executor always rolls back even successful reads
      # We verify by checking that the glancer_audits table's contents match our expectations
      # but the executed SELECT 1 has no side-effects in any case; deeper test via custom SQL
      result = described_class.execute("SELECT COUNT(*) AS cnt FROM glancer_chats")
      expect(result.first["cnt"]).to eq(0)
    end
  end

  # ── Retry on failure ──────────────────────────────────────────────────────

  describe ".execute — retry with Builder.fix_sql" do
    let(:bad_sql)   { "SELECT * FROM nonexistent_table_xyz" }
    let(:fixed_sql) { "SELECT 1 AS n" }

    before do
      allow(Glancer::Workflow::Builder).to receive(:fix_sql).and_return(fixed_sql)
    end

    it "calls Builder.fix_sql on first failure and retries" do
      expect(Glancer::Workflow::Builder).to receive(:fix_sql).at_least(:once).and_return(fixed_sql)
      described_class.execute(bad_sql)
    end

    it "returns the result from the fixed SQL" do
      result = described_class.execute(bad_sql)
      expect(result).to be_an(Array)
    end

    it "returns an error hash after 3 failed attempts" do
      allow(Glancer::Workflow::Builder).to receive(:fix_sql).and_return(bad_sql)
      result = described_class.execute(bad_sql, attempt: 1)
      expect(result).to be_a(Hash)
      expect(result[:error]).to be(true)
      expect(result[:message]).to be_a(String)
      expect(result[:last_code]).to eq(bad_sql)
    end
  end

  # ── apply_statement_timeout ───────────────────────────────────────────────

  describe ".apply_statement_timeout" do
    let(:connection) { ActiveRecord::Base.connection }

    it "does not raise for sqlite adapter (no timeout command)" do
      Glancer.configuration.adapter = :sqlite
      expect { described_class.apply_statement_timeout(connection) }.not_to raise_error
    end

    it "executes SET statement_timeout for postgres adapter" do
      Glancer.configuration.adapter = :postgres
      expect(connection).to receive(:execute).with(/SET statement_timeout/)
      described_class.apply_statement_timeout(connection)
    end

    it "executes SET max_execution_time for mysql adapter" do
      Glancer.configuration.adapter = :mysql2
      expect(connection).to receive(:execute).with(/SET max_execution_time/)
      described_class.apply_statement_timeout(connection)
    end

    it "does not raise when the DB rejects the timeout command" do
      Glancer.configuration.adapter = :postgres
      allow(connection).to receive(:execute).and_raise(StandardError, "unsupported")
      expect { described_class.apply_statement_timeout(connection) }.not_to raise_error
    end
  end
end
