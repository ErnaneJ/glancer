# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::SQLValidator do
  before do
    # Seed a schema embedding so the validator can find the "users" table.
    Glancer::Embedding.create!(
      content: "create_table users ...",
      embedding: [],
      source_type: "schema",
      source_path: "db/schema.rb#users"
    )
    Glancer::Embedding.create!(
      content: "create_table orders ...",
      embedding: [],
      source_type: "schema",
      source_path: "db/schema.rb#orders"
    )
  end

  # ── validate_tables_exist! ────────────────────────────────────────────────

  describe ".validate_tables_exist!" do
    it "does not raise when all tables in the SQL are indexed" do
      sql = "SELECT * FROM users"
      expect { described_class.validate_tables_exist!(sql) }.not_to raise_error
    end

    it "does not raise for a query referencing an indexed table via FROM" do
      sql = "SELECT u.id FROM users u"
      expect { described_class.validate_tables_exist!(sql) }.not_to raise_error
    end

    it "does not raise for a subquery referencing two indexed tables" do
      sql = "SELECT * FROM orders WHERE user_id IN (SELECT id FROM users)"
      expect { described_class.validate_tables_exist!(sql) }.not_to raise_error
    end

    it "raises Glancer::Error when a table is not indexed" do
      sql = "SELECT * FROM missing_table"
      expect { described_class.validate_tables_exist!(sql) }
        .to raise_error(Glancer::Error, /missing_table/)
    end

    it "raises Glancer::Error wrapping the underlying message" do
      sql = "SELECT * FROM ghost_table"
      expect { described_class.validate_tables_exist!(sql) }
        .to raise_error(Glancer::Error)
    end

    it "does not raise for system schema tables (sqlite_master)" do
      sql = "SELECT * FROM sqlite_master"
      expect { described_class.validate_tables_exist!(sql) }.not_to raise_error
    end
  end

  # ── extract_table_names ───────────────────────────────────────────────────

  describe ".extract_table_names" do
    it "extracts a single table name" do
      result = described_class.extract_table_names("SELECT * FROM users")
      expect(result).to contain_exactly("users")
    end

    it "extracts the FROM table (JOIN tables are not captured by the FROM regex)" do
      # extract_table_names only scans for 'from tablename' patterns.
      # JOIN keyword tables are NOT extracted because they have no FROM before them.
      sql = "SELECT * FROM orders JOIN users ON orders.user_id = users.id"
      result = described_class.extract_table_names(sql)
      expect(result).to include("orders")
    end

    it "extracts tables from multiple FROM clauses (e.g. subqueries)" do
      sql = "SELECT * FROM orders WHERE user_id IN (SELECT id FROM users)"
      result = described_class.extract_table_names(sql)
      expect(result).to include("orders", "users")
    end

    it "extracts table names from subqueries" do
      sql = "SELECT * FROM (SELECT id FROM products) sub"
      result = described_class.extract_table_names(sql)
      expect(result).to include("products")
    end

    it "is case-insensitive for the FROM keyword" do
      result = described_class.extract_table_names("SELECT * from users")
      expect(result).to include("users")
    end

    it "handles quoted table names by stripping quotes" do
      result = described_class.extract_table_names('SELECT * FROM "users"')
      expect(result).to include("users")
    end

    it "downcases table names" do
      result = described_class.extract_table_names("SELECT * FROM Users")
      expect(result).to include("users")
    end

    it "returns unique table names" do
      sql = "SELECT * FROM users JOIN users u2 ON users.id = u2.id"
      result = described_class.extract_table_names(sql)
      expect(result.count("users")).to eq(1)
    end
  end

  # ── system_table? ─────────────────────────────────────────────────────────

  describe ".system_table?" do
    it "returns true for sqlite_master when adapter is sqlite" do
      expect(described_class.system_table?("sqlite_master")).to be(true)
    end

    it "returns false for a user table" do
      expect(described_class.system_table?("orders")).to be(false)
    end

    it "returns true for a schema-qualified system table" do
      Glancer.configuration.adapter = :postgres
      expect(described_class.system_table?("information_schema.tables")).to be(true)
    end
  end

  # ── indexed_schema_table_names ────────────────────────────────────────────

  describe ".indexed_schema_table_names" do
    it "returns table names from schema embeddings" do
      result = described_class.indexed_schema_table_names
      expect(result).to include("users", "orders")
    end

    it "returns an empty array when no schema embeddings exist" do
      Glancer::Embedding.where(source_type: "schema").delete_all
      expect(described_class.indexed_schema_table_names).to eq([])
    end

    it "ignores non-schema embeddings" do
      Glancer::Embedding.create!(
        content: "model content", embedding: [], source_type: "models", source_path: "user.rb"
      )
      result = described_class.indexed_schema_table_names
      expect(result).not_to include(nil)
    end
  end
end
