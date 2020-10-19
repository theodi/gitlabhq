# frozen_string_literal: true

# Get user activity feed for projects common for a user and a logged in user
#
# - current_user: The user viewing the events
#                 WARNING: does not consider project feature visibility!
# - user: The user for which to load the events
# - params:
#   - limit: Number of items that to be returned. Defaults to 20 and limited to 100.
#   - offset: The page of events to return
class UserRecentEventsFinder
  prepend FinderWithCrossProjectAccess
  include FinderMethods
  include Gitlab::Allowable

  requires_cross_project_access

  attr_reader :current_user, :target_user, :params

  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100

  def initialize(current_user, target_user, params = {})
    @current_user = current_user
    @target_user = target_user
    @params = params
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def execute
    return Event.none unless can?(current_user, :read_user_profile, target_user)

    recent_events(params[:offset] || 0)
      .joins(:project)
      .with_associations
      .limit_recent(limit, params[:offset])
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  # rubocop: disable CodeReuse/ActiveRecord
  def recent_events(offset)
    sql = <<~SQL
      (#{projects}) AS projects_for_join
      JOIN (#{target_events.to_sql}) AS #{Event.table_name}
        ON #{Event.table_name}.project_id = projects_for_join.id
    SQL

    # Workaround for https://github.com/rails/rails/issues/24193
    Event.from([Arel.sql(sql)])
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def target_events
    Event.where(author: target_user)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def projects
    target_user.project_interactions.to_sql
  end

  def limit
    return DEFAULT_LIMIT unless params[:limit].present?

    [params[:limit].to_i, MAX_LIMIT].min
  end
end
