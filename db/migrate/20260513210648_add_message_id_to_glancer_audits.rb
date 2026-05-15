# frozen_string_literal: true

class AddMessageIdToGlancerAudits < ActiveRecord::Migration[6.1]
  def change
    add_column :glancer_audits, :message_id, :bigint
    add_index :glancer_audits, :message_id
  end
end
