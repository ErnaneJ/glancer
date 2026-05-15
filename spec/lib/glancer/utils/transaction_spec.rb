# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Utils::Transaction do
  describe ".make" do
    it "yields the connection to the block" do
      yielded = nil
      described_class.make { |conn| yielded = conn }
      expect(yielded).not_to be_nil
    end

    it "returns the result of the block" do
      result = described_class.make { |_conn| 42 }
      expect(result).to eq(42)
    end

    it "re-raises standard errors from the block" do
      expect { described_class.make { raise StandardError, "boom" } }
        .to raise_error(StandardError, "boom")
    end

    it "logs a warning when connection is still open after transaction" do
      conn = ActiveRecord::Base.connection
      allow(conn).to receive(:transaction_open?).and_return(true)

      expect(Glancer::Utils::Logger).to receive(:warn).with("Utils::Transaction", /not closed/)
      described_class.make { |_conn| }
    end
  end

  describe ".read_only_connection" do
    context "when read_only_db is nil" do
      it "returns nil" do
        Glancer.configuration.read_only_db = nil
        expect(described_class.read_only_connection).to be_nil
      end
    end

    context "when read_only_db is set" do
      before { Glancer.configuration.read_only_db = "sqlite3::memory:" }

      after { Glancer.configuration.read_only_db = nil }

      it "sets @used_read_only to true and returns the connection" do
        fake_pool = double("pool", connection: ActiveRecord::Base.connection)
        allow(ActiveRecord::Base).to receive(:establish_connection).and_return(fake_pool)
        conn = described_class.read_only_connection
        expect(conn).not_to be_nil
      end

      it "raises Glancer::Error when establish_connection fails" do
        allow(ActiveRecord::Base).to receive(:establish_connection).and_raise(StandardError, "connection refused")
        expect { described_class.read_only_connection }
          .to raise_error(Glancer::Error, /Read-only DB connection failed/)
      end
    end
  end

  describe ".connection_config_name" do
    it "returns the pool db_config name for a real connection" do
      conn = ActiveRecord::Base.connection
      result = described_class.connection_config_name(conn)
      expect(result).to be_a(String)
    end

    it "returns 'unknown' when pool info is unavailable" do
      fake_conn = double("connection")
      allow(fake_conn).to receive(:pool).and_raise(StandardError, "no pool")
      expect(described_class.connection_config_name(fake_conn)).to eq("unknown")
    end
  end
end
