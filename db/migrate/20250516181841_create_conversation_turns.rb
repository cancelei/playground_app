class CreateConversationTurns < ActiveRecord::Migration[8.0]
  def change
    create_table :conversation_turns do |t|
      t.string :role
      t.text :content
      t.string :session_id

      t.timestamps
    end
  end
end
