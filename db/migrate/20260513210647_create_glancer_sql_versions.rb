# frozen_string_literal: true

class CreateGlancerSqlVersions < ActiveRecord::Migration[6.1]
  def change
    table_name = table_exists?(:glancer_code_versions) ? :glancer_code_versions : :glancer_sql_versions

    create_table table_name do |t|
      t.references :message, null: false, foreign_key: { to_table: :glancer_messages }
      t.text :code, null: false
      t.string :source, null: false, default: "generated"
      t.timestamps
    end

    add_index table_name, :created_at
  rescue ActiveRecord::StatementInvalid
    # Table already exists — skip
  end
end
