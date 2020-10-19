# frozen_string_literal: true

require 'fast_spec_helper'
require 'rubocop'
require_relative '../../../../rubocop/cop/migration/add_concurrent_foreign_key'

RSpec.describe RuboCop::Cop::Migration::AddConcurrentForeignKey, type: :rubocop do
  include CopHelper

  let(:cop) { described_class.new }

  context 'outside of a migration' do
    it 'does not register any offenses' do
      inspect_source('def up; add_foreign_key(:projects, :users, column: :user_id); end')

      expect(cop.offenses).to be_empty
    end
  end

  context 'in a migration' do
    before do
      allow(cop).to receive(:in_migration?).and_return(true)
    end

    it 'registers an offense when using add_foreign_key' do
      inspect_source('def up; add_foreign_key(:projects, :users, column: :user_id); end')

      aggregate_failures do
        expect(cop.offenses.size).to eq(1)
        expect(cop.offenses.map(&:line)).to eq([1])
      end
    end

    it 'does not register an offense when a `NOT VALID` foreign key is added' do
      inspect_source('def up; add_foreign_key(:projects, :users, column: :user_id, validate: false); end')

      expect(cop.offenses).to be_empty
    end

    it 'does not register an offense when `add_foreign_key` is within `with_lock_retries`' do
      inspect_source <<~RUBY
        with_lock_retries do
          add_foreign_key :key, :projects, column: :project_id, on_delete: :cascade
        end
      RUBY

      expect(cop.offenses).to be_empty
    end
  end
end
