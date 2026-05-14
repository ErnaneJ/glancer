class AddUserEditedSqlToGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:glancer_messages, :user_edited_sql)
      add_column :glancer_messages, :user_edited_sql, :boolean, default: false, null: false
    end
  end
end
