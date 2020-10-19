# frozen_string_literal: true

class SubmitUsagePingService
  PRODUCTION_URL = 'https://version.gitlab.com/usage_data'
  STAGING_URL = 'https://gitlab-services-version-gitlab-com-staging.gs-staging.gitlab.org/usage_data'

  METRICS = %w[leader_issues instance_issues percentage_issues leader_notes instance_notes
               percentage_notes leader_milestones instance_milestones percentage_milestones
               leader_boards instance_boards percentage_boards leader_merge_requests
               instance_merge_requests percentage_merge_requests leader_ci_pipelines
               instance_ci_pipelines percentage_ci_pipelines leader_environments instance_environments
               percentage_environments leader_deployments instance_deployments percentage_deployments
               leader_projects_prometheus_active instance_projects_prometheus_active
               percentage_projects_prometheus_active leader_service_desk_issues instance_service_desk_issues
               percentage_service_desk_issues].freeze

  SubmissionError = Class.new(StandardError)

  def execute
    return unless Gitlab::CurrentSettings.usage_ping_enabled?
    return if User.single_user&.requires_usage_stats_consent?

    usage_data = Gitlab::UsageData.data(force_refresh: true)

    raise SubmissionError.new('Usage data is blank') if usage_data.blank?

    raw_usage_data = save_raw_usage_data(usage_data)

    response = Gitlab::HTTP.post(
      url,
      body: usage_data.to_json,
      allow_local_requests: true,
      headers: { 'Content-type' => 'application/json' }
    )

    raise SubmissionError.new("Unsuccessful response code: #{response.code}") unless response.success?

    raw_usage_data.update_sent_at! if raw_usage_data

    store_metrics(response)
  end

  private

  def save_raw_usage_data(usage_data)
    return unless Feature.enabled?(:save_raw_usage_data)

    RawUsageData.safe_find_or_create_by(recorded_at: usage_data[:recorded_at]) do |record|
      record.payload = usage_data
    end
  end

  def store_metrics(response)
    metrics = response['conv_index'] || response['dev_ops_score'] # leaving dev_ops_score here, as the response data comes from the gitlab-version-com

    return unless metrics.present?

    DevOpsReport::Metric.create!(
      metrics.slice(*METRICS)
    )
  end

  # See https://gitlab.com/gitlab-org/gitlab/-/issues/233615 for details
  def url
    if Rails.env.production?
      PRODUCTION_URL
    else
      STAGING_URL
    end
  end
end
