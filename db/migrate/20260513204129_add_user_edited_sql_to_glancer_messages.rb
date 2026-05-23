# frozen_string_literal: true

class AddUserEditedSqlToGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    # Column was renamed to user_edited_code; skip if either name already exists
    return if column_exists?(:glancer_messages, :user_edited_code)
    return if column_exists?(:glancer_messages, :user_edited_sql)

    add_column :glancer_messages, :user_edited_code, :boolean, default: false, null: false
  end
end
