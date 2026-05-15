# frozen_string_literal: true

class AddLlmModelToGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    return if column_exists?(:glancer_messages, :llm_model)

    add_column :glancer_messages, :llm_model, :string
  end
end
