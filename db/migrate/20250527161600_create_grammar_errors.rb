class CreateGrammarErrors < ActiveRecord::Migration[8.0]
  def change
    create_table :grammar_errors do |t|
      t.references :transcription, null: false, foreign_key: true
      t.string :error_type, null: false
      t.string :error_description, null: false
      t.integer :position, null: false
      t.integer :length, null: false

      t.timestamps
    end
  end
end
