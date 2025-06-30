module Glancer
  class Audit < ApplicationRecord
    self.table_name = "glancer_audits"

    validates :sql, :adapter, :run_id, :executed_at, presence: true
    validates :run_id, uniqueness: true
  end
end
