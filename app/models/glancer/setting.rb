module Glancer
  class Setting < ApplicationRecord
    self.table_name = "glancer_settings"

    validates :key, presence: true, uniqueness: true

    def self.get(key, default: nil)
      find_by(key: key.to_s)&.value || default
    end

    def self.set(key, value)
      record = find_or_initialize_by(key: key.to_s)
      record.value = value.to_s
      record.save!
    end

    def self.set_many(hash)
      hash.each { |k, v| set(k, v) }
    end
  end
end
