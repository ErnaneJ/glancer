# frozen_string_literal: true

class RenameCodeColumnInGlancerAudits < ActiveRecord::Migration[6.1]
  def change
    rename_column :glancer_audits, :sql, :code if column_exists?(:glancer_audits, :sql)
  end
end
