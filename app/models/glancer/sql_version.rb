module Glancer
  class SqlVersion < ApplicationRecord
    self.table_name = "glancer_sql_versions"

    belongs_to :message, class_name: "Glancer::Message"
    enum source: { generated: "generated", user_edited: "user_edited" }

    validates :sql, :source, presence: true
  end
end
