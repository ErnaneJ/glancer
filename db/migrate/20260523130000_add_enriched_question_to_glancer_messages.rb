# frozen_string_literal: true

class AddEnrichedQuestionToGlancerMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :glancer_messages, :enriched_question, :text
  end
end
