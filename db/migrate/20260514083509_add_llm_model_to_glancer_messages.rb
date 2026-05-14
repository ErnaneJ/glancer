class AddLlmModelToGlancerMessages < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:glancer_messages, :llm_model)
      add_column :glancer_messages, :llm_model, :string
    end
  end
end
