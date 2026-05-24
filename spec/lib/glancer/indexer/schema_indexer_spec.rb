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

  let(:inflections_path) { Pathname.new("/fake/root/config/initializers/inflections.rb") }

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new("/fake/root"))
    allow(Rails).to receive(:application).and_return(double("app", eager_load!: nil))
    allow(File).to receive(:exist?).with(schema_path).and_return(true)
    allow(File).to receive(:exist?).with(inflections_path).and_return(false)
    allow(File).to receive(:read).with(schema_path).and_return(schema_content)
    # Prevent AR descendants from polluting results
    allow(ActiveRecord::Base).to receive(:descendants).and_return([])
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

    it "silently skips chunks whose table name cannot be extracted" do
      # Use {nonstandard} so extract_table_name regex cannot match [a-zA-Z0-9_]+
      schema_without_name = "  create_table {nonstandard} do |t|\n    t.string :foo\n  end\n"
      allow(File).to receive(:read).with(schema_path).and_return(schema_without_name)
      result = described_class.index!
      table_chunks = result.reject { |c| c[:source_path].to_s.end_with?("#foreign_keys") }
      expect(table_chunks).to be_empty
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

  # ── eager_load_models! ────────────────────────────────────────────────────

  describe ".eager_load_models!" do
    it "calls Rails.application.eager_load!" do
      app = double("app")
      allow(Rails).to receive(:application).and_return(app)
      expect(app).to receive(:eager_load!)
      described_class.eager_load_models!
    end

    it "does not raise when eager_load! raises" do
      allow(Rails).to receive(:application).and_return(double("app", eager_load!: nil).tap do |a|
        allow(a).to receive(:eager_load!).and_raise(StandardError, "boom")
      end)
      expect { described_class.eager_load_models! }.not_to raise_error
    end
  end

  # ── find_model_for_table ──────────────────────────────────────────────────

  describe ".find_model_for_table" do
    let(:fake_model) do
      Class.new(ActiveRecord::Base) do
        def self.name = "FakeUser"
        def self.table_name = "users"
        def self.abstract_class? = false
      end
    end

    it "returns nil when no descendants match" do
      allow(ActiveRecord::Base).to receive(:descendants).and_return([])
      expect(described_class.find_model_for_table("users")).to be_nil
    end

    it "returns the model whose table_name matches" do
      allow(ActiveRecord::Base).to receive(:descendants).and_return([fake_model])
      expect(described_class.find_model_for_table("users")).to eq(fake_model)
    end

    it "excludes Glancer-namespaced models" do
      glancer_model = Class.new(ActiveRecord::Base) do
        def self.name = "Glancer::Embedding"
        def self.table_name = "users"
        def self.abstract_class? = false
      end
      allow(ActiveRecord::Base).to receive(:descendants).and_return([glancer_model])
      expect(described_class.find_model_for_table("users")).to be_nil
    end

    it "returns nil when descendants raises" do
      allow(ActiveRecord::Base).to receive(:descendants).and_raise(StandardError, "fail")
      expect(described_class.find_model_for_table("users")).to be_nil
    end
  end

  # ── model_associations_block ──────────────────────────────────────────────

  describe ".model_associations_block" do
    it "returns empty string when no model found for table" do
      allow(described_class).to receive(:find_model_for_table).and_return(nil)
      expect(described_class.model_associations_block("users")).to eq("")
    end

    it "returns empty string when model has no associations" do
      model = Class.new(ActiveRecord::Base) do
        def self.name = "FakeUser"
        def self.reflect_on_all_associations = []
      end
      allow(described_class).to receive(:find_model_for_table).and_return(model)
      expect(described_class.model_associations_block("users")).to eq("")
    end

    it "returns a formatted associations block when associations exist" do
      assoc = double("assoc",
                     macro: :has_many,
                     name: :orders,
                     class_name: "Order",
                     foreign_key: "user_id",
                     options: {})
      model = double("FakeUser", name: "FakeUser", reflect_on_all_associations: [assoc])
      allow(described_class).to receive(:find_model_for_table).and_return(model)
      result = described_class.model_associations_block("users")
      expect(result).to include("ActiveRecord Associations (FakeUser)")
      expect(result).to include("has_many :orders")
    end
  end

  # ── format_association ────────────────────────────────────────────────────

  describe ".format_association" do
    def make_assoc(macro:, name:, class_name:, foreign_key:, options: {})
      double("assoc", macro: macro, name: name, class_name: class_name,
                      foreign_key: foreign_key, options: options)
    end

    it "formats a simple belongs_to" do
      assoc = make_assoc(macro: :belongs_to, name: :user, class_name: "User", foreign_key: "user_id")
      result = described_class.format_association(assoc)
      expect(result).to include("belongs_to :user")
      expect(result).to include('class_name: "User"')
      expect(result).to include('foreign_key: "user_id"')
    end

    it "includes through option when present" do
      assoc = make_assoc(macro: :has_many, name: :products, class_name: "Product",
                         foreign_key: "id", options: { through: :line_items })
      result = described_class.format_association(assoc)
      expect(result).to include("through: :line_items")
    end

    it "includes polymorphic: true when set" do
      assoc = make_assoc(macro: :belongs_to, name: :imageable, class_name: "Imageable",
                         foreign_key: "imageable_id", options: { polymorphic: true })
      result = described_class.format_association(assoc)
      expect(result).to include("polymorphic: true")
    end

    it "includes dependent option when present" do
      assoc = make_assoc(macro: :has_many, name: :posts, class_name: "Post",
                         foreign_key: "user_id", options: { dependent: :destroy })
      result = described_class.format_association(assoc)
      expect(result).to include("dependent: :destroy")
    end
  end

  # ── extract_inflections ───────────────────────────────────────────────────

  describe ".extract_inflections" do
    it "returns nil when inflections file does not exist" do
      allow(File).to receive(:exist?).with(inflections_path).and_return(false)
      expect(described_class.extract_inflections).to be_nil
    end

    it "returns nil when file exists but has no inflect.* rules" do
      allow(File).to receive(:exist?).with(inflections_path).and_return(true)
      allow(File).to receive(:read).with(inflections_path).and_return("# empty\n")
      expect(described_class.extract_inflections).to be_nil
    end

    it "returns a chunk hash when inflect rules are present" do
      raw = "ActiveSupport::Inflector.inflections(:en) do |inflect|\n  inflect.irregular 'person', 'people'\nend\n"
      allow(File).to receive(:exist?).with(inflections_path).and_return(true)
      allow(File).to receive(:read).with(inflections_path).and_return(raw)
      result = described_class.extract_inflections
      expect(result).to be_a(Hash)
      expect(result[:source_type]).to eq("schema")
      expect(result[:content]).to include("Custom Rails Inflections")
      expect(result[:content]).to include("inflect.irregular")
    end

    it "returns nil when File.read raises" do
      allow(File).to receive(:exist?).with(inflections_path).and_return(true)
      allow(File).to receive(:read).with(inflections_path).and_raise(IOError, "no read")
      expect(described_class.extract_inflections).to be_nil
    end
  end

  # ── index! enrichment ─────────────────────────────────────────────────────

  describe ".index! with associations and inflections" do
    it "appends associations block to table chunks when a model is found" do
      assoc = double("assoc", macro: :has_many, name: :orders, class_name: "Order",
                              foreign_key: "user_id", options: {})
      model = double("User", name: "User", reflect_on_all_associations: [assoc])
      allow(described_class).to receive(:find_model_for_table).and_return(nil)
      allow(described_class).to receive(:find_model_for_table).with("users").and_return(model)

      result = described_class.index!
      users_chunk = result.find { |c| c[:source_path].to_s.include?("#users") }
      expect(users_chunk[:content]).to include("ActiveRecord Associations (User)")
    end

    it "appends inflections chunk when inflections file contains rules" do
      raw = "ActiveSupport::Inflector.inflections(:en) do |inflect|\n  inflect.irregular 'ox', 'oxen'\nend\n"
      allow(File).to receive(:exist?).with(inflections_path).and_return(true)
      allow(File).to receive(:read).with(inflections_path).and_return(raw)

      result = described_class.index!
      inflect_chunk = result.find { |c| c[:source_path].to_s.include?("inflections.rb") }
      expect(inflect_chunk).not_to be_nil
      expect(inflect_chunk[:content]).to include("inflect.irregular")
    end

    it "does not append inflections chunk when file has no rules" do
      allow(File).to receive(:exist?).with(inflections_path).and_return(true)
      allow(File).to receive(:read).with(inflections_path).and_return("# nothing here\n")

      result = described_class.index!
      inflect_chunk = result.find { |c| c[:source_path].to_s.include?("inflections.rb") }
      expect(inflect_chunk).to be_nil
    end
  end
end
