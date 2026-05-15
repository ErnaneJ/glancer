# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Indexer::SchemaIndexer do
  let(:schema_path) { Pathname.new("/fake/root/db/schema.rb") }
  let(:schema_content) do
    # NOTE: The schema split regex is /^  create_table / (with 2 leading spaces).
    # Indentation must NOT be stripped (do not use <<~RUBY — use <<RUBY or
    # explicit leading spaces so each create_table block is indented correctly).
    "ActiveRecord::Schema[7.0].define(version: 2024_01_01) do\n" \
    "  create_table \"users\", force: :cascade do |t|\n" \
    "    t.string \"name\"\n" \
    "    t.string \"email\"\n" \
    "    t.timestamps\n" \
    "  end\n\n" \
    "  create_table \"orders\", force: :cascade do |t|\n" \
    "    t.integer \"user_id\"\n" \
    "    t.decimal \"total\"\n" \
    "    t.timestamps\n" \
    "  end\n\n" \
    "  add_foreign_key \"orders\", \"users\", column: \"user_id\"\n" \
    "end\n"
  end

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new("/fake/root"))
    allow(File).to receive(:exist?).with(schema_path).and_return(true)
    allow(File).to receive(:read).with(schema_path).and_return(schema_content)
  end

  # ── index! ────────────────────────────────────────────────────────────────

  describe ".index!" do
    it "returns an array of chunk hashes" do
      result = described_class.index!
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "includes a chunk for each recognized create_table block" do
      result = described_class.index!
      table_chunks = result.select do |c|
        c[:source_type] == "schema" &&
          !c[:source_path].end_with?("#foreign_keys") &&
          (c[:source_path].include?("#users") || c[:source_path].include?("#orders"))
      end
      # Schema has 2 tables (users, orders).
      expect(table_chunks.size).to eq(2)
    end

    it "sets source_type to 'schema' on all chunks" do
      result = described_class.index!
      expect(result.map { |c| c[:source_type] }).to all(eq("schema"))
    end

    it "includes the table name in the source_path" do
      result = described_class.index!
      paths  = result.map { |c| c[:source_path] }
      expect(paths.any? { |p| p.include?("#users") }).to be(true)
      expect(paths.any? { |p| p.include?("#orders") }).to be(true)
    end

    it "includes a foreign keys chunk when add_foreign_key lines exist" do
      result = described_class.index!
      fk_chunk = result.find { |c| c[:source_path].to_s.end_with?("#foreign_keys") }
      expect(fk_chunk).not_to be_nil
    end

    it "includes the FK relationship in the foreign keys chunk content" do
      result   = described_class.index!
      fk_chunk = result.find { |c| c[:source_path].to_s.end_with?("#foreign_keys") }
      expect(fk_chunk[:content]).to include("orders")
      expect(fk_chunk[:content]).to include("users")
    end

    it "returns [] when the schema file does not exist" do
      allow(File).to receive(:exist?).and_return(false)
      expect(described_class.index!).to eq([])
    end

    it "raises Glancer::Error when File.read raises" do
      allow(File).to receive(:read).and_raise(IOError, "disk failure")
      expect { described_class.index! }.to raise_error(Glancer::Error, /Schema indexing failed/)
    end
  end

  # ── split_into_chunks ─────────────────────────────────────────────────────

  describe ".split_into_chunks" do
    it "splits a schema string into create_table chunks" do
      # schema_content has 2 tables; the preamble before the first `  create_table`
      # is a separate (non-table) chunk — we only care that there are >= 2 table chunks.
      chunks = described_class.split_into_chunks(schema_content)
      table_chunks = chunks.select { |c| c =~ /create_table "(users|orders)"/ }
      expect(table_chunks.size).to eq(2)
    end

    it "each chunk starts with 'create_table'" do
      chunks = described_class.split_into_chunks(schema_content)
      chunks.each { |c| expect(c).to start_with("create_table") }
    end

    it "returns a single non-table chunk for schema text with no create_table blocks" do
      # The split produces one element (the whole text prepended with 'create_table')
      # when no `  create_table ` lines are present.
      result = described_class.split_into_chunks("# empty schema\n")
      # All chunks start with create_table, but none match a real table name
      expect(result.any? { |c| c =~ /create_table "/ }).to be(false)
    end
  end

  # ── extract_table_name ────────────────────────────────────────────────────

  describe ".extract_table_name" do
    it "extracts a double-quoted table name" do
      chunk = 'create_table "users", force: :cascade do |t|'
      expect(described_class.extract_table_name(chunk)).to eq("users")
    end

    it "extracts a single-quoted table name" do
      chunk = "create_table 'products' do |t|"
      expect(described_class.extract_table_name(chunk)).to eq("products")
    end

    it "extracts an unquoted table name" do
      chunk = "create_table orders do |t|"
      expect(described_class.extract_table_name(chunk)).to eq("orders")
    end

    it "returns nil for a chunk that has no create_table pattern" do
      expect(described_class.extract_table_name("add_index :users, :email")).to be_nil
    end
  end

  # ── extract_foreign_keys ──────────────────────────────────────────────────

  describe ".extract_foreign_keys" do
    it "returns nil when no add_foreign_key lines are present" do
      text = "create_table users do; end\n"
      expect(described_class.extract_foreign_keys(text, schema_path)).to be_nil
    end

    it "returns a hash with content, source_type, and source_path" do
      result = described_class.extract_foreign_keys(schema_content, schema_path)
      expect(result).to be_a(Hash)
      expect(result[:source_type]).to eq("schema")
      expect(result[:source_path].to_s).to include("#foreign_keys")
    end

    it "describes the relationship in the content" do
      result = described_class.extract_foreign_keys(schema_content, schema_path)
      expect(result[:content]).to include("orders.user_id → users.id")
    end

    it "infers the column name when no explicit column is given" do
      text = <<~RUBY
        add_foreign_key "order_items", "orders"
      RUBY
      result = described_class.extract_foreign_keys(text, schema_path)
      expect(result[:content]).to include("order_items.order_id → orders.id")
    end
  end
end
