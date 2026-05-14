# frozen_string_literal: true
class AddUserEditedSqlToGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    return if column_exists?(:glancer_messages, :user_edited_sql)

    add_column :glancer_messages, :user_edited_sql, :boolean, default: false, null: false
  end
end
