# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LimitedCapacity::Worker, :clean_gitlab_redis_queues, :aggregate_failures do
  let(:worker_class) do
    Class.new do
      def self.name
        'DummyWorker'
      end

      include ApplicationWorker
      include LimitedCapacity::Worker
    end
  end

  let(:worker) { worker_class.new }

  let(:job_tracker) do
    LimitedCapacity::JobTracker.new(worker_class.name)
  end

  before do
    worker.jid = 'my-jid'
    allow(worker).to receive(:job_tracker).and_return(job_tracker)
  end

  describe 'required methods' do
    it { expect { worker.perform_work }.to raise_error(NotImplementedError) }
    it { expect { worker.remaining_work_count }.to raise_error(NotImplementedError) }
    it { expect { worker.max_running_jobs }.to raise_error(NotImplementedError) }
  end

  describe 'Sidekiq options' do
    it 'does not retry failed jobs' do
      expect(worker_class.sidekiq_options['retry']).to eq(0)
    end

    it 'does not deduplicate jobs' do
      expect(worker_class.get_deduplicate_strategy).to eq(:none)
    end
  end

  describe '.perform_with_capacity' do
    subject(:perform_with_capacity) { worker_class.perform_with_capacity(:arg) }

    before do
      expect_next_instance_of(worker_class) do |instance|
        expect(instance).to receive(:remove_failed_jobs)
        expect(instance).to receive(:report_prometheus_metrics)

        allow(instance).to receive(:remaining_work_count).and_return(remaining_work_count)
        allow(instance).to receive(:remaining_capacity).and_return(remaining_capacity)
      end
    end

    context 'when capacity is larger than work' do
      let(:remaining_work_count) { 2 }
      let(:remaining_capacity) { 3 }

      it 'enqueues jobs for remaining work' do
        expect(worker_class)
          .to receive(:bulk_perform_async)
          .with([[:arg], [:arg]])

        perform_with_capacity
      end
    end

    context 'when capacity is lower than work' do
      let(:remaining_work_count) { 5 }
      let(:remaining_capacity) { 3 }

      it 'enqueues jobs for remaining work' do
        expect(worker_class)
          .to receive(:bulk_perform_async)
          .with([[:arg], [:arg], [:arg]])

        perform_with_capacity
      end
    end
  end

  describe '#perform' do
    subject(:perform) { worker.perform(:arg) }

    context 'with capacity' do
      before do
        allow(worker).to receive(:max_running_jobs).and_return(10)
        allow(worker).to receive(:running_jobs_count).and_return(0)
        allow(worker).to receive(:remaining_work_count).and_return(0)
      end

      it 'calls perform_work' do
        expect(worker).to receive(:perform_work).with(:arg)

        perform
      end

      it 're-enqueues itself' do
        allow(worker).to receive(:perform_work)
        expect(worker).to receive(:re_enqueue).with(:arg)

        perform
      end

      it 'registers itself in the running set' do
        allow(worker).to receive(:perform_work)
        expect(job_tracker).to receive(:register).with('my-jid')

        perform
      end

      it 'removes itself from the running set' do
        expect(job_tracker).to receive(:remove).with('my-jid')

        allow(worker).to receive(:perform_work)

        perform
      end

      it 'reports prometheus metrics' do
        allow(worker).to receive(:perform_work)
        expect(worker).to receive(:report_prometheus_metrics)

        perform
      end
    end

    context 'with capacity and without work' do
      before do
        allow(worker).to receive(:max_running_jobs).and_return(10)
        allow(worker).to receive(:running_jobs_count).and_return(0)
        allow(worker).to receive(:remaining_work_count).and_return(0)
        allow(worker).to receive(:perform_work)
      end

      it 'does not re-enqueue itself' do
        expect(worker_class).not_to receive(:perform_async)

        perform
      end
    end

    context 'without capacity' do
      before do
        allow(worker).to receive(:max_running_jobs).and_return(10)
        allow(worker).to receive(:running_jobs_count).and_return(15)
        allow(worker).to receive(:remaining_work_count).and_return(10)
      end

      it 'does not call perform_work' do
        expect(worker).not_to receive(:perform_work)

        perform
      end

      it 'does not re-enqueue itself' do
        expect(worker_class).not_to receive(:perform_async)

        perform
      end

      it 'does not register in the running set' do
        expect(job_tracker).not_to receive(:register)

        perform
      end

      it 'removes itself from the running set' do
        expect(job_tracker).to receive(:remove).with('my-jid')

        perform
      end

      it 'reports prometheus metrics' do
        expect(worker).to receive(:report_prometheus_metrics)

        perform
      end
    end

    context 'when perform_work fails' do
      it 'does not re-enqueue itself' do
        expect(worker).not_to receive(:re_enqueue)

        expect { perform }.to raise_error(NotImplementedError)
      end

      it 'removes itself from the running set' do
        expect(job_tracker).to receive(:remove)

        expect { perform }.to raise_error(NotImplementedError)
      end

      it 'reports prometheus metrics' do
        expect(worker).to receive(:report_prometheus_metrics)

        expect { perform }.to raise_error(NotImplementedError)
      end
    end
  end

  describe '#remaining_capacity' do
    subject(:remaining_capacity) { worker.remaining_capacity }

    before do
      expect(worker).to receive(:max_running_jobs).and_return(max_capacity)
    end

    context 'when changing the capacity to a lower value' do
      let(:max_capacity) { -1 }

      it { expect(remaining_capacity).to eq(0) }
    end

    context 'when registering new jobs' do
      let(:max_capacity) { 2 }

      before do
        job_tracker.register('a-job-id')
      end

      it { expect(remaining_capacity).to eq(1) }
    end

    context 'with jobs in the queue' do
      let(:max_capacity) { 2 }

      before do
        expect(worker_class).to receive(:queue_size).and_return(1)
      end

      it { expect(remaining_capacity).to eq(1) }
    end

    context 'with both running jobs and queued jobs' do
      let(:max_capacity) { 10 }

      before do
        expect(worker_class).to receive(:queue_size).and_return(5)
        expect(worker).to receive(:running_jobs_count).and_return(3)
      end

      it { expect(remaining_capacity).to eq(2) }
    end
  end

  describe '#remove_failed_jobs' do
    subject(:remove_failed_jobs) { worker.remove_failed_jobs }

    before do
      job_tracker.register('a-job-id')
      allow(worker).to receive(:max_running_jobs).and_return(2)

      expect(job_tracker).to receive(:clean_up).and_call_original
    end

    context 'with failed jobs' do
      it 'update the available capacity' do
        expect { remove_failed_jobs }.to change { worker.remaining_capacity }.by(1)
      end
    end
  end

  describe '#report_prometheus_metrics' do
    subject(:report_prometheus_metrics) { worker.report_prometheus_metrics }

    before do
      allow(worker).to receive(:running_jobs_count).and_return(5)
      allow(worker).to receive(:max_running_jobs).and_return(7)
      allow(worker).to receive(:remaining_work_count).and_return(9)
    end

    it 'reports number of running jobs' do
      labels = { worker: 'DummyWorker' }

      report_prometheus_metrics

      expect(Gitlab::Metrics.registry.get(:limited_capacity_worker_running_jobs).get(labels)).to eq(5)
      expect(Gitlab::Metrics.registry.get(:limited_capacity_worker_max_running_jobs).get(labels)).to eq(7)
      expect(Gitlab::Metrics.registry.get(:limited_capacity_worker_remaining_work_count).get(labels)).to eq(9)
    end
  end
end
