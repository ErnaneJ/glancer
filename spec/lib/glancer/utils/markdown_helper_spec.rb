# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Utils::MarkdownHelper do
  describe ".markdown_to_html" do
    it "converts basic markdown headings to HTML" do
      result = described_class.markdown_to_html("# Hello")
      expect(result).to include("<h1>")
      expect(result).to include("Hello")
    end

    it "converts bold markdown to <strong>" do
      result = described_class.markdown_to_html("**bold text**")
      expect(result).to include("<strong>")
    end

    it "converts a markdown paragraph" do
      result = described_class.markdown_to_html("simple paragraph")
      expect(result).to include("simple paragraph")
    end

    it "wraps markdown tables in .table-scroll-wrapper" do
      md = "| col1 | col2 |\n|------|------|\n| a    | b    |"
      result = described_class.markdown_to_html(md)
      expect(result).to include("table-scroll-wrapper")
      expect(result).to include("table-scroll-inner")
      expect(result).to include("<table")
    end

    it "wraps multiple tables independently" do
      md = "| a | b |\n|---|---|\n| 1 | 2 |\n\ntext\n\n| c | d |\n|---|---|\n| 3 | 4 |"
      result = described_class.markdown_to_html(md)
      expect(result.scan("table-scroll-wrapper").size).to eq(2)
    end

    it "returns a String" do
      expect(described_class.markdown_to_html("hello")).to be_a(String)
    end
  end

  describe ".highlight_mentions" do
    it "leaves content inside fenced code blocks untouched" do
      text = "```\n@users table here\n```"
      result = described_class.highlight_mentions(text)
      expect(result).to include("@users")
      expect(result).not_to include("glancer-mention")
    end

    it "skips @mention when valid_set is provided and mention is not in it" do
      result = described_class.highlight_mentions("check @unknown table", valid_tables: %w[users orders])
      expect(result).to include("@unknown")
      expect(result).not_to include("glancer-mention")
    end

    it "wraps a valid @mention in a link without schema_base" do
      result = described_class.highlight_mentions("check @users table", valid_tables: %w[users])
      expect(result).to include('class="glancer-mention"')
      expect(result).to include("@users")
      expect(result).to include('href="#"')
    end

    it "wraps a valid @mention in a link with schema_base" do
      result = described_class.highlight_mentions("see @orders", schema_base: "/glancer", valid_tables: %w[orders])
      expect(result).to include('href="/glancer?table=orders"')
      expect(result).to include('target="_blank"')
    end
  end

  describe ".extract_sql_from_markdown" do
    it "extracts SQL from a ```sql...``` fenced block" do
      markdown = "Some text\n```sql\nSELECT 1\n```\nMore text"
      expect(described_class.extract_sql_from_markdown(markdown)).to eq("SELECT 1")
    end

    it "returns empty string when no sql block is present" do
      expect(described_class.extract_sql_from_markdown("no code here")).to eq("")
    end

    it "returns empty string for a plain ``` block without sql hint" do
      markdown = "```\nSELECT 1\n```"
      expect(described_class.extract_sql_from_markdown(markdown)).to eq("")
    end

    it "handles multi-line SQL correctly" do
      markdown = "```sql\nSELECT id,\n  name\nFROM users\n```"
      result = described_class.extract_sql_from_markdown(markdown)
      expect(result).to include("SELECT id,")
      expect(result).to include("FROM users")
    end
  end
end
