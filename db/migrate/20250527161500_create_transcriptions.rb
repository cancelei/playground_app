class CreateTranscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :transcriptions do |t|
      t.text :text_content, null: false
      
      t.timestamps
    end
  end
end
