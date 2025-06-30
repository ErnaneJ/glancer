class CreateGlancerAudits < ActiveRecord::Migration[6.1]
  def change
    create_table :glancer_audits do |t|
      t.text :question
      t.text :sql, null: false
      t.string :adapter, null: false
      t.string :run_id, null: false
      t.datetime :executed_at, null: false

      t.timestamps
    end

    add_index :glancer_audits, :run_id, unique: true
    add_index :glancer_audits, :executed_at
  end
end
