# frozen_string_literal: true

module Glancer
  class CodeVersion < ApplicationRecord
    self.table_name = "glancer_code_versions"

    belongs_to :message, class_name: "Glancer::Message"
    enum source: { generated: "generated", user_edited: "user_edited" }

    validates :code, :source, presence: true
  end
end
