# frozen_string_literal: true

class AddStatusToGlancerMessages < ActiveRecord::Migration[7.0]
  def change
    # 0=pending, 1=processing, 2=complete, 3=failed
    # default 2 (complete) so existing records are treated as already done.
    add_column :glancer_messages, :status, :integer, default: 2, null: false
  end
end
