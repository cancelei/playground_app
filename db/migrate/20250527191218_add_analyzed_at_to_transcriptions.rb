class AddAnalyzedAtToTranscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :transcriptions, :analyzed_at, :datetime
  end
end
