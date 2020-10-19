# frozen_string_literal: true

require 'active_record'
require 'active_record/log_subscriber'

module Gitlab
  module SidekiqLogging
    class StructuredLogger
      include LogsJobs

      def call(job, queue)
        started_time = get_time
        base_payload = parse_job(job)
        ActiveRecord::LogSubscriber.reset_runtime

        Sidekiq.logger.info log_job_start(base_payload)

        yield

        Sidekiq.logger.info log_job_done(job, started_time, base_payload)
      rescue => job_exception
        Sidekiq.logger.warn log_job_done(job, started_time, base_payload, job_exception)

        raise
      end

      private

      def add_instrumentation_keys!(job, output_payload)
        output_payload.merge!(job.slice(*::Gitlab::InstrumentationHelper.keys))
      end

      def add_logging_extras!(job, output_payload)
        output_payload.merge!(
          job.select { |key, _| key.to_s.start_with?("#{ApplicationWorker::LOGGING_EXTRA_KEY}.") }
        )
      end

      def add_db_counters!(job, output_payload)
        output_payload.merge!(job.slice(*::Gitlab::Metrics::Subscribers::ActiveRecord::DB_COUNTERS))
      end

      def log_job_start(payload)
        payload['message'] = "#{base_message(payload)}: start"
        payload['job_status'] = 'start'

        scheduling_latency_s = ::Gitlab::InstrumentationHelper.queue_duration_for_job(payload)
        payload['scheduling_latency_s'] = scheduling_latency_s if scheduling_latency_s

        payload
      end

      def log_job_done(job, started_time, payload, job_exception = nil)
        payload = payload.dup
        add_instrumentation_keys!(job, payload)
        add_logging_extras!(job, payload)
        add_db_counters!(job, payload)

        elapsed_time = elapsed(started_time)
        add_time_keys!(elapsed_time, payload)

        message = base_message(payload)

        if job_exception
          payload['message'] = "#{message}: fail: #{payload['duration_s']} sec"
          payload['job_status'] = 'fail'
          payload['error_message'] = job_exception.message
          payload['error_class'] = job_exception.class.name
        else
          payload['message'] = "#{message}: done: #{payload['duration_s']} sec"
          payload['job_status'] = 'done'
        end

        db_duration = ActiveRecord::LogSubscriber.runtime
        payload['db_duration_s'] = Gitlab::Utils.ms_to_round_sec(db_duration)

        payload
      end

      def add_time_keys!(time, payload)
        payload['duration_s'] = time[:duration].round(Gitlab::InstrumentationHelper::DURATION_PRECISION)

        # ignore `cpu_s` if the platform does not support Process::CLOCK_THREAD_CPUTIME_ID (time[:cputime] == 0)
        # supported OS version can be found at: https://www.rubydoc.info/stdlib/core/2.1.6/Process:clock_gettime
        payload['cpu_s'] = time[:cputime].round(Gitlab::InstrumentationHelper::DURATION_PRECISION) if time[:cputime] > 0
        payload['completed_at'] = Time.now.utc.to_f
      end

      def elapsed(t0)
        t1 = get_time
        {
          duration: t1[:now] - t0[:now],
          cputime: t1[:thread_cputime] - t0[:thread_cputime]
        }
      end

      def get_time
        {
          now: current_time,
          thread_cputime: defined?(Process::CLOCK_THREAD_CPUTIME_ID) ? Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) : 0
        }
      end

      def current_time
        Gitlab::Metrics::System.monotonic_time
      end
    end
  end
end
