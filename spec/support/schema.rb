# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :glancer_chats, force: :cascade do |t|
    t.string :title
    t.timestamps
  end

  create_table :glancer_messages, force: :cascade do |t|
    t.integer :chat_id, null: false
    t.integer :user_message_id
    t.string  :role
    t.text    :content
    t.text    :sql
    t.boolean :successful,       default: true
    t.boolean :user_edited_sql,  default: false, null: false
    t.string  :llm_model
    t.timestamps
  end

  create_table :glancer_embeddings, force: :cascade do |t|
    t.text    :content, null: false
    t.text    :embedding # serialised Array via serialize :embedding, Array
    t.string  :source_type
    t.string  :source_path
    t.timestamps
  end

  create_table :glancer_audits, force: :cascade do |t|
    t.text     :question
    t.text     :sql,         null: false
    t.string   :adapter,     null: false
    t.string   :run_id,      null: false
    t.datetime :executed_at, null: false
    t.integer  :message_id
    t.timestamps
  end

  create_table :glancer_sql_versions, force: :cascade do |t|
    t.integer :message_id, null: false
    t.text    :sql,        null: false
    t.string  :source,     null: false, default: "generated"
    t.timestamps
  end

  create_table :glancer_settings, force: :cascade do |t|
    t.string :key, null: false
    t.text   :value
    t.timestamps
  end
end
