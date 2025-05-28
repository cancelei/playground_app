class CreateGrammarCorrections < ActiveRecord::Migration[8.0]
  def change
    create_table :grammar_corrections do |t|
      t.references :grammar_error, null: false, foreign_key: true
      t.string :corrected_text, null: false
      t.text :explanation, null: false

      t.timestamps
    end
  end
end
