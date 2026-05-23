# frozen_string_literal: true

class CreateGlancerAudits < ActiveRecord::Migration[6.1]
  def change
    create_table :glancer_audits do |t|
      t.text :question
      t.text :code, null: false
      t.string :code_type, null: false, default: "sql"
      t.string :adapter, null: false
      t.string :run_id, null: false
      t.datetime :executed_at, null: false

      t.timestamps
    end

    add_index :glancer_audits, :run_id, unique: true
    add_index :glancer_audits, :executed_at
  end
end
