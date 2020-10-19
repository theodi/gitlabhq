# frozen_string_literal: true

class ClusterWaitForAppUpdateWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include ClusterQueue
  include ClusterApplications

  INTERVAL = 10.seconds
  TIMEOUT = 20.minutes

  loggable_arguments 0

  def perform(app_name, app_id)
    find_application(app_name, app_id) do |app|
      ::Clusters::Applications::CheckUpgradeProgressService.new(app).execute
    end
  end
end
