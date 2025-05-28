module AnalyticsHelper
  # Group records by week
  def group_by_week(scope, timestamp_field)
    # Use Arel.sql to safely wrap raw SQL expressions
    scope.group(Arel.sql("DATE_TRUNC('week', #{timestamp_field})")).order(Arel.sql("DATE_TRUNC('week', #{timestamp_field})"))
  end
end
