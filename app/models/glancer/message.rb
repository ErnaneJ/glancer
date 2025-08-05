module Glancer
  class Message < ApplicationRecord
    belongs_to :chat, class_name: "Glancer::Chat"
    has_one :user_message, class_name: "Glancer::Message", foreign_key: :user_message_id, dependent: :nullify
    enum role: { user: "user", assistant: "assistant", system: "system" }
    validates :content, presence: true
  end
end
