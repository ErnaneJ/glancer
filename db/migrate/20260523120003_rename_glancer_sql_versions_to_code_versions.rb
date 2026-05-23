# frozen_string_literal: true

class RenameGlancerSqlVersionsToCodeVersions < ActiveRecord::Migration[6.1]
  def change
    rename_table :glancer_sql_versions, :glancer_code_versions if table_exists?(:glancer_sql_versions)
    rename_column :glancer_code_versions, :sql, :code if column_exists?(:glancer_code_versions, :sql)
  end
end
