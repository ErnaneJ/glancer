# frozen_string_literal: true

class RenameCodeColumnsInGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    rename_column :glancer_messages, :sql, :code if column_exists?(:glancer_messages, :sql)
    rename_column :glancer_messages, :user_edited_sql, :user_edited_code if column_exists?(:glancer_messages, :user_edited_sql)
  end
end
