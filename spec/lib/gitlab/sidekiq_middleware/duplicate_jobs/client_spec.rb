# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqMiddleware::DuplicateJobs::Client, :clean_gitlab_redis_queues do
  let(:worker_class) do
    Class.new do
      def self.name
        'TestDeduplicationWorker'
      end

      include ApplicationWorker

      def perform(*args)
      end
    end
  end

  before do
    stub_const('TestDeduplicationWorker', worker_class)
  end

  describe '#call' do
    it 'adds a correct duplicate tag to the jobs', :aggregate_failures do
      TestDeduplicationWorker.bulk_perform_async([['args1'], ['args2'], ['args1']])

      job1, job2, job3 = TestDeduplicationWorker.jobs

      expect(job1['duplicate-of']).to be_nil
      expect(job2['duplicate-of']).to be_nil
      expect(job3['duplicate-of']).to eq(job1['jid'])
    end

    context 'without scheduled deduplication' do
      it "does not mark a job that's scheduled in the future as a duplicate" do
        TestDeduplicationWorker.perform_async('args1')
        TestDeduplicationWorker.perform_at(1.day.from_now, 'args1')
        TestDeduplicationWorker.perform_in(3.hours, 'args1')

        duplicates = TestDeduplicationWorker.jobs.map { |job| job['duplicate-of'] }

        expect(duplicates).to all(be_nil)
      end
    end

    context 'with scheduled deduplication' do
      let(:scheduled_worker_class) do
        Class.new do
          def self.name
            'TestDeduplicationWorker'
          end

          include ApplicationWorker

          deduplicate :until_executing, including_scheduled: true

          def perform(*args)
          end
        end
      end

      before do
        stub_const('TestDeduplicationWorker', scheduled_worker_class)
      end

      it 'adds a correct duplicate tag to the jobs', :aggregate_failures do
        TestDeduplicationWorker.perform_async('args1')
        TestDeduplicationWorker.perform_at(1.day.from_now, 'args1')
        TestDeduplicationWorker.perform_in(3.hours, 'args1')
        TestDeduplicationWorker.perform_in(3.hours, 'args2')

        job1, job2, job3, job4 = TestDeduplicationWorker.jobs

        expect(job1['duplicate-of']).to be_nil
        expect(job2['duplicate-of']).to eq(job1['jid'])
        expect(job3['duplicate-of']).to eq(job1['jid'])
        expect(job4['duplicate-of']).to be_nil
      end
    end
  end
end
