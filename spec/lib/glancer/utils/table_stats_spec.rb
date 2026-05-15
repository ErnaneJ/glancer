# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Utils::TableStats do
  describe ".count_for" do
    context "when the table exists and is valid" do
      it "returns the row count" do
        Glancer::Chat.create!(title: "A")
        Glancer::Chat.create!(title: "B")
        expect(described_class.count_for("glancer_chats")).to eq(2)
      end

      it "returns 0 for an empty table" do
        expect(described_class.count_for("glancer_chats")).to eq(0)
      end
    end

    context "when the table name is invalid" do
      it "returns -1 for a table not in the DB" do
        expect(described_class.count_for("nonexistent_xyz_table")).to eq(-1)
      end
    end

    context "when the DB query fails" do
      it "returns -1 and logs a warning" do
        allow(Glancer::Configuration).to receive(:valid_table_name?).and_return(true)
        allow(ActiveRecord::Base.connection).to receive(:select_value)
          .and_raise(StandardError, "DB down")
        expect(described_class.count_for("glancer_chats")).to eq(-1)
      end
    end
  end
end
