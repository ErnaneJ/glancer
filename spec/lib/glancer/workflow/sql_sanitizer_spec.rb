# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Workflow::SQLSanitizer do
  describe ".ensure_safe!" do
    context "with safe SELECT queries" do
      it "passes a simple SELECT without raising" do
        expect { described_class.ensure_safe!("SELECT * FROM users") }.not_to raise_error
      end

      it "passes a SELECT with a JOIN" do
        sql = "SELECT u.id, o.total FROM users u JOIN orders o ON u.id = o.user_id"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end

      it "passes a WITH (CTE) query" do
        sql = "WITH cte AS (SELECT id FROM users) SELECT * FROM cte"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end
    end

    context "with forbidden keywords" do
      %w[DELETE UPDATE INSERT DROP TRUNCATE ALTER CREATE REPLACE].each do |keyword|
        it "raises Glancer::Error when SQL contains #{keyword}" do
          sql = "#{keyword} FROM users"
          expect { described_class.ensure_safe!(sql) }.to raise_error(Glancer::Error, /#{keyword.downcase}/i)
        end

        it "raises Glancer::Error regardless of case for #{keyword}" do
          sql = "#{keyword.downcase} FROM users"
          expect { described_class.ensure_safe!(sql) }.to raise_error(Glancer::Error)
        end
      end
    end

    context "when a forbidden keyword appears inside a string literal" do
      it "does NOT raise for DELETE inside a string value" do
        sql = "SELECT * FROM users WHERE action = 'delete this record'"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end

      it "does NOT raise for UPDATE inside a string value" do
        sql = "SELECT notes FROM logs WHERE notes = 'update pending'"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end

      it "does NOT raise for DROP inside a string value" do
        sql = "SELECT * FROM archive WHERE label = 'drop unused'"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end
    end

    context "when a forbidden keyword appears inside an inline comment" do
      it "does NOT raise for DELETE inside a -- comment" do
        sql = "SELECT * FROM users -- delete this comment is harmless"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end

      it "does NOT raise for DROP inside a /* */ block comment" do
        sql = "SELECT 1 /* DROP TABLE users */"
        expect { described_class.ensure_safe!(sql) }.not_to raise_error
      end
    end

    context "with mixed-case forbidden keywords" do
      it "raises for 'Delete' (title case)" do
        expect { described_class.ensure_safe!("Delete FROM users") }.to raise_error(Glancer::Error)
      end

      it "raises for 'dRoP'" do
        expect { described_class.ensure_safe!("dRoP TABLE users") }.to raise_error(Glancer::Error)
      end
    end
  end

  describe ".strip_strings_and_comments" do
    it "removes single-quoted string literals" do
      result = described_class.strip_strings_and_comments("select 'hello world' from t")
      expect(result).not_to include("hello world")
    end

    it "removes inline -- comments" do
      result = described_class.strip_strings_and_comments("select 1 -- this is a comment\nfrom t")
      expect(result).not_to include("this is a comment")
    end

    it "removes block /* */ comments" do
      result = described_class.strip_strings_and_comments("select /* drop tables */ 1")
      expect(result).not_to include("drop tables")
    end

    it "preserves the SQL structure outside of stripped sections" do
      result = described_class.strip_strings_and_comments("select id from users")
      expect(result).to include("select id from users")
    end
  end
end
