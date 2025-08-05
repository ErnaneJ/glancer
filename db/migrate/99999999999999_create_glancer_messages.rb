# 20250629212644_create_glancer_messages.rb
class CreateGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    drop_table :glancer_messages, if_exists: true

    create_table :glancer_messages do |t|
      t.references :chat, null: false, foreign_key: { to_table: :glancer_chats }
      t.references :user_message, null: true, foreign_key: { to_table: :glancer_messages }
      t.string :role
      t.text :content
      t.text :sql
      t.timestamps
    end
  end
end
