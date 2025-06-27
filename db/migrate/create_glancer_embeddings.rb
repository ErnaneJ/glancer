class CreateGlancerEmbeddings < ActiveRecord::Migration[7.0]
  def change
    create_table :glancer_embeddings do |t|
      t.text :content, null: false
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
        t.jsonb :embedding, null: false
      else
        t.json :embedding, null: false
      end
      t.string :source_type
      t.string :source_path
      t.timestamps
    end
  end
end
