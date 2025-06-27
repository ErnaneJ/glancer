class CreateGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :glancer_messages do |t|
      t.references :chat, null: false, foreign_key: { to_table: :glancer_chats }
      t.string :role
      t.text :content
      t.timestamps
    end
  end
end
