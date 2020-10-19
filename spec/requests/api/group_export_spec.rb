# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupExport do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:path) { "/groups/#{group.id}/export" }
  let(:download_path) { "/groups/#{group.id}/export/download" }

  let(:export_path) { "#{Dir.tmpdir}/group_export_spec" }

  before do
    allow_next_instance_of(Gitlab::ImportExport) do |import_export|
      expect(import_export).to receive(:storage_path).and_return(export_path)
    end
  end

  after do
    FileUtils.rm_rf(export_path, secure: true)
  end

  describe 'GET /groups/:group_id/export/download' do
    let(:upload) { ImportExportUpload.new(group: group) }

    before do
      stub_uploads_object_storage(ImportExportUploader)

      group.add_owner(user)
    end

    context 'group_import_export feature flag enabled' do
      before do
        stub_feature_flags(group_import_export: true)

        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:increment)
          .and_return(0)
      end

      context 'when export file exists' do
        before do
          upload.export_file = fixture_file_upload('spec/fixtures/group_export.tar.gz', "`/tar.gz")
          upload.save!
        end

        it 'downloads exported group archive' do
          get api(download_path, user)

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when export_file.file does not exist' do
          before do
            expect_next_instance_of(ImportExportUploader) do |uploader|
              expect(uploader).to receive(:file).and_return(nil)
            end
          end

          it 'returns 404' do
            get api(download_path, user)

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when export file does not exist' do
        it 'returns 404' do
          get api(download_path, user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'group_import_export feature flag disabled' do
      before do
        stub_feature_flags(group_import_export: false)
      end

      it 'responds with 404 Not Found' do
        get api(download_path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the requests have exceeded the rate limit' do
      before do
        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:increment)
          .and_return(Gitlab::ApplicationRateLimiter.rate_limits[:group_download_export][:threshold].call + 1)
      end

      it 'throttles the endpoint' do
        get api(download_path, user)

        expect(json_response["message"])
          .to include('error' => 'This endpoint has been requested too many times. Try again later.')
        expect(response).to have_gitlab_http_status :too_many_requests
      end
    end
  end

  describe 'POST /groups/:group_id/export' do
    context 'group_import_export feature flag enabled' do
      before do
        stub_feature_flags(group_import_export: true)
      end

      context 'when user is a group owner' do
        before do
          group.add_owner(user)
        end

        it 'accepts download' do
          post api(path, user)

          expect(response).to have_gitlab_http_status(:accepted)
        end
      end

      context 'when the export cannot be started' do
        before do
          group.add_owner(user)
          allow(GroupExportWorker).to receive(:perform_async).and_return(nil)
        end

        it 'returns an error' do
          post api(path, user)

          expect(response).to have_gitlab_http_status(:error)
        end
      end

      context 'when user is not a group owner' do
        before do
          group.add_developer(user)
        end

        it 'forbids the request' do
          post api(path, user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'group_import_export feature flag disabled' do
      before do
        stub_feature_flags(group_import_export: false)
      end

      it 'responds with 404 Not Found' do
        post api(path, user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the requests have exceeded the rate limit' do
      before do
        group.add_owner(user)

        allow(Gitlab::ApplicationRateLimiter)
          .to receive(:increment)
          .and_return(Gitlab::ApplicationRateLimiter.rate_limits[:group_export][:threshold].call + 1)
      end

      it 'throttles the endpoint' do
        post api(path, user)

        expect(json_response["message"])
          .to include('error' => 'This endpoint has been requested too many times. Try again later.')
        expect(response).to have_gitlab_http_status :too_many_requests
      end
    end
  end
end
