class CreateGlancerSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :glancer_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :glancer_settings, :key, unique: true
  end
end
