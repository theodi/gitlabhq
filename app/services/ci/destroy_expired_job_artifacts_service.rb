# frozen_string_literal: true

module Ci
  class DestroyExpiredJobArtifactsService
    include ::Gitlab::ExclusiveLeaseHelpers
    include ::Gitlab::LoopHelpers

    BATCH_SIZE = 100
    LOOP_TIMEOUT = 45.minutes
    LOOP_LIMIT = 1000
    EXCLUSIVE_LOCK_KEY = 'expired_job_artifacts:destroy:lock'
    LOCK_TIMEOUT = 50.minutes

    ##
    # Destroy expired job artifacts on GitLab instance
    #
    # This destroy process cannot run for more than 45 minutes. This is for
    # preventing multiple `ExpireBuildArtifactsWorker` CRON jobs run concurrently,
    # which is scheduled at every hour.
    def execute
      in_lock(EXCLUSIVE_LOCK_KEY, ttl: LOCK_TIMEOUT, retries: 1) do
        loop_until(timeout: LOOP_TIMEOUT, limit: LOOP_LIMIT) do
          destroy_batch(Ci::JobArtifact) || destroy_batch(Ci::PipelineArtifact)
        end
      end
    end

    private

    def destroy_batch(klass)
      artifact_batch = if klass == Ci::JobArtifact
                         klass.expired(BATCH_SIZE).unlocked
                       else
                         klass.expired(BATCH_SIZE)
                       end

      artifacts = artifact_batch.to_a

      return false if artifacts.empty?

      artifacts.each(&:destroy!)
      run_after_destroy(artifacts)

      true # This is required because of the design of `loop_until` method.
    end

    def run_after_destroy(artifacts); end
  end
end

Ci::DestroyExpiredJobArtifactsService.prepend_if_ee('EE::Ci::DestroyExpiredJobArtifactsService')
