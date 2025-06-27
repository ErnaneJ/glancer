module Glancer
  class Message < ApplicationRecord
    belongs_to :chat, class_name: "Glancer::Chat"
    enum role: { user: "user", assistant: "assistant", system: "system" }
    validates :content, presence: true
  end
end
