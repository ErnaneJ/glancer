# frozen_string_literal: true

class CreateGlancerSqlVersions < ActiveRecord::Migration[6.1]
  def change
    create_table :glancer_sql_versions do |t|
      t.references :message, null: false, foreign_key: { to_table: :glancer_messages }
      t.text :sql, null: false
      t.string :source, null: false, default: "generated"
      t.timestamps
    end

    add_index :glancer_sql_versions, :created_at
  end
end
