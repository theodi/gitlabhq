# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User activates HipChat', :js do
  include_context 'project service activation'

  context 'with standard settings' do
    before do
      stub_request(:post, /.*api.hipchat.com.*/)
    end

    it 'activates service' do
      visit_project_integration('HipChat')
      fill_in('Room', with: 'gitlab')
      fill_in('Token', with: 'verySecret')

      click_test_then_save_integration(expect_test_to_fail: false)

      expect(page).to have_content('HipChat settings saved and active.')
    end
  end

  context 'with custom settings' do
    before do
      stub_request(:post, /.*chat.example.com.*/)
    end

    it 'activates service' do
      visit_project_integration('HipChat')
      fill_in('Room', with: 'gitlab_custom')
      fill_in('Token', with: 'secretCustom')
      fill_in('Server', with: 'https://chat.example.com')

      click_test_then_save_integration(expect_test_to_fail: false)

      expect(page).to have_content('HipChat settings saved and active.')
    end
  end
end
