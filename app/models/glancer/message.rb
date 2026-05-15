# frozen_string_literal: true

module Glancer
  class Message < ApplicationRecord
    belongs_to :chat, class_name: "Glancer::Chat"
    belongs_to :user_message, class_name: "Glancer::Message", optional: true
    has_many :sql_versions, class_name: "Glancer::SqlVersion", dependent: :destroy
    has_many :audits, class_name: "Glancer::Audit", foreign_key: :message_id, dependent: :nullify

    # Nullify self-referential FK before destroy to avoid MySQL constraint violation
    # when the chat cascade reaches user messages before their assistant counterparts
    before_destroy { self.class.where(user_message_id: id).update_all(user_message_id: nil) }
    enum role: { user: "user", assistant: "assistant", system: "system" }
    validates :content, presence: true

    def sql_result_json
      JSON.parse(content || "[]")
    rescue JSON::ParserError
      []
    end
  end
end
