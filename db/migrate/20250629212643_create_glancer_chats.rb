class CreateGlancerChats < ActiveRecord::Migration[6.1]
  def change
    create_table :glancer_chats do |t|
      t.string :title
      t.timestamps
    end
  end
end
