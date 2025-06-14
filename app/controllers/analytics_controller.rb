class AnalyticsController < ApplicationController
  include AnalyticsHelper
  before_action :check_user_registration

  def index
    # Get counts of errors by type
    @error_type_counts = GrammarError.group(:error_type).count

    # Get most common errors
    @most_common_errors = GrammarError.select("error_description, COUNT(*) as count")
                                     .group(:error_description)
                                     .order("count DESC")
                                     .limit(10)

    # Get user progress over time (errors per week)
    @weekly_errors = group_by_week(GrammarError.joins(:transcription), "transcriptions.created_at").count
  end
end
