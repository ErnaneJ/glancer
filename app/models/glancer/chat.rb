module Glancer
  class Chat < ApplicationRecord
    has_many :messages, class_name: "Glancer::Message", dependent: :destroy
    validates :title, presence: true
  end
end
