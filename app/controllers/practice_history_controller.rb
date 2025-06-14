class PracticeHistoryController < ApplicationController
  before_action :check_user_registration

  def index
    @transcriptions = Transcription.includes(:grammar_errors)
                                   .where.not(grammar_errors: { id: nil })
                                   .order(created_at: :desc)

    if params[:error_type].present?
      @transcriptions = @transcriptions.joins(:grammar_errors)
                                       .where(grammar_errors: { error_type: params[:error_type] })
                                       .distinct
    end
  end
end
