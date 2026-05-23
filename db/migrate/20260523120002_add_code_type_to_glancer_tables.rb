# frozen_string_literal: true

class AddCodeTypeToGlancerTables < ActiveRecord::Migration[6.1]
  def change
    add_column :glancer_messages, :code_type, :string, null: false, default: "sql" unless column_exists?(:glancer_messages, :code_type)
    return if column_exists?(:glancer_audits, :code_type)

    add_column :glancer_audits, :code_type, :string, null: false, default: "sql"
  end
end
