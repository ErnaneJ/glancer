# frozen_string_literal: true
module Glancer
  class Audit < ApplicationRecord
    self.table_name = "glancer_audits"

    belongs_to :message, class_name: "Glancer::Message", optional: true

    validates :sql, :adapter, :run_id, :executed_at, presence: true
    validates :run_id, uniqueness: true
  end
end
