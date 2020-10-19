# frozen_string_literal: true

module Ci
  class DailyBuildGroupReportResultsFinder
    include Gitlab::Allowable

    def initialize(current_user:, project:, ref_path:, start_date:, end_date:, limit: nil)
      @current_user = current_user
      @project = project
      @ref_path = ref_path
      @start_date = start_date
      @end_date = end_date
      @limit = limit
    end

    def execute
      return none unless query_allowed?

      query
    end

    protected

    attr_reader :current_user, :project, :ref_path, :start_date, :end_date, :limit

    def query
      Ci::DailyBuildGroupReportResult.recent_results(
        query_params,
        limit: limit
      )
    end

    def query_allowed?
      can?(current_user, :read_build_report_results, project)
    end

    def query_params
      {
        project_id: project,
        ref_path: ref_path,
        date: start_date..end_date
      }
    end

    def none
      Ci::DailyBuildGroupReportResult.none
    end
  end
end
