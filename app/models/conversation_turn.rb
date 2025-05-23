class ConversationTurn < ApplicationRecord
  after_create_commit do
    broadcast_append_to "conversation_turns_#{session_id}"
  end
end
