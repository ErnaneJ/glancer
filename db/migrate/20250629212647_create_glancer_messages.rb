# frozen_string_literal: true

# 20250629212644_create_glancer_messages.rb
class CreateGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    # MySQL requires removing FKs from dependent tables before dropping the referenced table
    if table_exists?(:glancer_sql_versions) && foreign_key_exists?(:glancer_sql_versions, :glancer_messages)
      remove_foreign_key :glancer_sql_versions, :glancer_messages
    end

    drop_table :glancer_messages, if_exists: true

    create_table :glancer_messages do |t|
      t.references :chat, null: false, foreign_key: { to_table: :glancer_chats }
      t.references :user_message, null: true, foreign_key: { to_table: :glancer_messages }
      t.string :role
      t.text :content
      t.text :sql
      t.boolean :successful, default: true
      t.boolean :user_edited_sql, default: false, null: false
      t.string :llm_model
      t.timestamps
    end
  end
end
