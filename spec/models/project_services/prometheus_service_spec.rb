# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PrometheusService, :use_clean_rails_memory_store_caching, :snowplow do
  include PrometheusHelpers
  include ReactiveCachingHelpers

  let(:project) { create(:prometheus_project) }
  let(:service) { project.prometheus_service }

  describe "Associations" do
    it { is_expected.to belong_to :project }
  end

  context 'redirects' do
    it 'does not follow redirects' do
      redirect_to = 'https://redirected.example.com'
      redirect_req_stub = stub_prometheus_request(prometheus_query_url('1'), status: 302, headers: { location: redirect_to })
      redirected_req_stub = stub_prometheus_request(redirect_to, body: { 'status': 'success' })

      result = service.test

      # result = { success: false, result: error }
      expect(result[:success]).to be_falsy
      expect(result[:result]).to be_instance_of(Gitlab::PrometheusClient::UnexpectedResponseError)

      expect(redirect_req_stub).to have_been_requested
      expect(redirected_req_stub).not_to have_been_requested
    end
  end

  describe 'Validations' do
    context 'when manual_configuration is enabled' do
      before do
        service.manual_configuration = true
      end

      it 'validates presence of api_url' do
        expect(service).to validate_presence_of(:api_url)
      end
    end

    context 'when manual configuration is disabled' do
      before do
        service.manual_configuration = false
      end

      it 'does not validate presence of api_url' do
        expect(service).not_to validate_presence_of(:api_url)
        expect(service.valid?).to eq(true)
      end

      context 'local connections allowed' do
        before do
          stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)
        end

        it 'does not validate presence of api_url' do
          expect(service).not_to validate_presence_of(:api_url)
          expect(service.valid?).to eq(true)
        end
      end
    end

    context 'when the api_url domain points to localhost or local network' do
      let(:domain) { Addressable::URI.parse(service.api_url).hostname }

      it 'cannot query' do
        expect(service.can_query?).to be true

        aggregate_failures do
          ['127.0.0.1', '192.168.2.3'].each do |url|
            allow(Addrinfo).to receive(:getaddrinfo).with(domain, any_args).and_return([Addrinfo.tcp(url, 80)])

            expect(service.can_query?).to be false
          end
        end
      end

      it 'can query when local requests are allowed' do
        stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)

        aggregate_failures do
          ['127.0.0.1', '192.168.2.3'].each do |url|
            allow(Addrinfo).to receive(:getaddrinfo).with(domain, any_args).and_return([Addrinfo.tcp(url, 80)])

            expect(service.can_query?).to be true
          end
        end
      end

      context 'with self-monitoring project and internal Prometheus' do
        before do
          service.api_url = 'http://localhost:9090'

          stub_application_setting(self_monitoring_project_id: project.id)
          stub_config(prometheus: { enable: true, listen_address: 'localhost:9090' })
        end

        it 'allows self-monitoring project to connect to internal Prometheus' do
          aggregate_failures do
            ['127.0.0.1', '192.168.2.3'].each do |url|
              allow(Addrinfo).to receive(:getaddrinfo).with(domain, any_args).and_return([Addrinfo.tcp(url, 80)])

              expect(service.can_query?).to be true
            end
          end
        end

        it 'does not allow self-monitoring project to connect to other local URLs' do
          service.api_url = 'http://localhost:8000'

          aggregate_failures do
            ['127.0.0.1', '192.168.2.3'].each do |url|
              allow(Addrinfo).to receive(:getaddrinfo).with(domain, any_args).and_return([Addrinfo.tcp(url, 80)])

              expect(service.can_query?).to be false
            end
          end
        end
      end
    end
  end

  describe 'callbacks' do
    context 'after_create' do
      let(:project) { create(:project) }
      let(:service) { build(:prometheus_service, project: project) }

      subject(:create_service) { service.save! }

      it 'creates default alerts' do
        expect(Prometheus::CreateDefaultAlertsWorker)
          .to receive(:perform_async)
          .with(project.id)

        create_service
      end

      context 'no project exists' do
        let(:service) { build(:prometheus_service, :instance) }

        it 'does not create default alerts' do
          expect(Prometheus::CreateDefaultAlertsWorker)
            .not_to receive(:perform_async)

          create_service
        end
      end
    end
  end

  describe '#test' do
    before do
      service.manual_configuration = true
    end

    let!(:req_stub) { stub_prometheus_request(prometheus_query_url('1'), body: prometheus_value_body('vector')) }

    context 'success' do
      it 'reads the discovery endpoint' do
        expect(service.test[:result]).to eq('Checked API endpoint')
        expect(service.test[:success]).to be_truthy
        expect(req_stub).to have_been_requested.twice
      end
    end

    context 'failure' do
      let!(:req_stub) { stub_prometheus_request(prometheus_query_url('1'), status: 404) }

      it 'fails to read the discovery endpoint' do
        expect(service.test[:success]).to be_falsy
        expect(req_stub).to have_been_requested
      end
    end
  end

  describe '#prometheus_client' do
    let(:api_url) { 'http://some_url' }

    before do
      service.active = true
      service.api_url = api_url
      service.manual_configuration = manual_configuration
    end

    context 'manual configuration is enabled' do
      let(:manual_configuration) { true }

      it 'calls valid?' do
        allow(service).to receive(:valid?).and_call_original

        expect(service.prometheus_client).not_to be_nil

        expect(service).to have_received(:valid?)
      end
    end

    context 'manual configuration is disabled' do
      let(:manual_configuration) { false }

      it 'no client provided' do
        expect(service.prometheus_client).to be_nil
      end
    end

    context 'when local requests are allowed' do
      let(:manual_configuration) { true }
      let(:api_url) { 'http://192.168.1.1:9090' }

      before do
        stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)

        stub_prometheus_request("#{api_url}/api/v1/query?query=1")
      end

      it 'allows local requests' do
        expect(service.prometheus_client).not_to be_nil
        expect { service.prometheus_client.ping }.not_to raise_error
      end
    end

    context 'when local requests are blocked' do
      let(:manual_configuration) { true }
      let(:api_url) { 'http://192.168.1.1:9090' }

      before do
        stub_application_setting(allow_local_requests_from_web_hooks_and_services: false)

        stub_prometheus_request("#{api_url}/api/v1/query?query=1")
      end

      it 'blocks local requests' do
        expect(service.prometheus_client).to be_nil
      end

      context 'with self monitoring project and internal Prometheus URL' do
        before do
          stub_application_setting(allow_local_requests_from_web_hooks_and_services: false)
          stub_application_setting(self_monitoring_project_id: project.id)

          stub_config(prometheus: {
            enable: true,
            listen_address: api_url
          })
        end

        it 'allows local requests' do
          expect(service.prometheus_client).not_to be_nil
          expect { service.prometheus_client.ping }.not_to raise_error
        end
      end
    end

    context 'behind IAP' do
      let(:manual_configuration) { true }

      before do
        # dummy private key generated only for this test to pass openssl validation
        service.google_iap_service_account_json = '{"type":"service_account","private_key":"-----BEGIN RSA PRIVATE KEY-----\nMIIBOAIBAAJAU85LgUY5o6j6j/07GMLCNUcWJOBA1buZnNgKELayA6mSsHrIv31J\nY8kS+9WzGPQninea7DcM4hHA7smMgQD1BwIDAQABAkAqKxMy6PL3tn7dFL43p0ex\nJyOtSmlVIiAZG1t1LXhE/uoLpYi5DnbYqGgu0oih+7nzLY/dXpNpXUmiRMOUEKmB\nAiEAoTi2rBXbrLSi2C+H7M/nTOjMQQDuZ8Wr4uWpKcjYJTMCIQCFEskL565oFl/7\nRRQVH+cARrAsAAoJSbrOBAvYZ0PI3QIgIEFwis10vgEF86rOzxppdIG/G+JL0IdD\n9IluZuXAGPECIGUo7qSaLr75o2VEEgwtAFH5aptIPFjrL5LFCKwtdB4RAiAYZgFV\nHCMmaooAw/eELuMoMWNYmujZ7VaAnOewGDW0uw==\n-----END RSA PRIVATE KEY-----\n"}'
        service.google_iap_audience_client_id = "IAP_CLIENT_ID.apps.googleusercontent.com"

        stub_request(:post, "https://oauth2.googleapis.com/token").to_return(status: 200, body: '{"id_token": "FOO"}', headers: { 'Content-Type': 'application/json; charset=UTF-8' })
      end

      it 'includes the authorization header' do
        expect(service.prometheus_client).not_to be_nil
        expect(service.prometheus_client.send(:options)).to have_key(:headers)
        expect(service.prometheus_client.send(:options)[:headers]).to eq(authorization: "Bearer FOO")
      end
    end
  end

  describe '#prometheus_available?' do
    context 'clusters with installed prometheus' do
      before do
        create(:clusters_applications_prometheus, :installed, cluster: cluster)
      end

      context 'cluster belongs to project' do
        let(:cluster) { create(:cluster, projects: [project]) }

        it 'returns true' do
          expect(service.prometheus_available?).to be(true)
        end
      end

      context 'cluster belongs to projects group' do
        let_it_be(:group) { create(:group) }
        let(:project) { create(:prometheus_project, group: group) }
        let(:cluster) { create(:cluster_for_group, :with_installed_helm, groups: [group]) }

        it 'returns true' do
          expect(service.prometheus_available?).to be(true)
        end

        it 'avoids N+1 queries' do
          service
          5.times do |i|
            other_cluster = create(:cluster_for_group, :with_installed_helm, groups: [group], environment_scope: i)
            create(:clusters_applications_prometheus, :installing, cluster: other_cluster)
          end
          expect { service.prometheus_available? }.not_to exceed_query_limit(1)
        end
      end

      context 'cluster belongs to gitlab instance' do
        let(:cluster) { create(:cluster, :instance) }

        it 'returns true' do
          expect(service.prometheus_available?).to be(true)
        end
      end
    end

    context 'clusters with updated prometheus' do
      let!(:cluster) { create(:cluster, projects: [project]) }
      let!(:prometheus) { create(:clusters_applications_prometheus, :updated, cluster: cluster) }

      it 'returns true' do
        expect(service.prometheus_available?).to be(true)
      end
    end

    context 'clusters without prometheus installed' do
      let(:cluster) { create(:cluster, projects: [project]) }
      let!(:prometheus) { create(:clusters_applications_prometheus, cluster: cluster) }

      it 'returns false' do
        expect(service.prometheus_available?).to be(false)
      end
    end

    context 'clusters without prometheus' do
      let(:cluster) { create(:cluster, projects: [project]) }

      it 'returns false' do
        expect(service.prometheus_available?).to be(false)
      end
    end

    context 'no clusters' do
      it 'returns false' do
        expect(service.prometheus_available?).to be(false)
      end
    end
  end

  describe '#synchronize_service_state before_save callback' do
    context 'no clusters with prometheus are installed' do
      context 'when service is inactive' do
        before do
          service.active = false
        end

        it 'activates service when manual_configuration is enabled' do
          expect { service.update!(manual_configuration: true) }.to change { service.active }.from(false).to(true)
        end

        it 'keeps service inactive when manual_configuration is disabled' do
          expect { service.update!(manual_configuration: false) }.not_to change { service.active }.from(false)
        end
      end

      context 'when service is active' do
        before do
          service.active = true
        end

        it 'keeps the service active when manual_configuration is enabled' do
          expect { service.update!(manual_configuration: true) }.not_to change { service.active }.from(true)
        end

        it 'inactivates the service when manual_configuration is disabled' do
          expect { service.update!(manual_configuration: false) }.to change { service.active }.from(true).to(false)
        end
      end
    end

    context 'with prometheus installed in the cluster' do
      before do
        allow(service).to receive(:prometheus_available?).and_return(true)
      end

      context 'when service is inactive' do
        before do
          service.active = false
        end

        it 'activates service when manual_configuration is enabled' do
          expect { service.update!(manual_configuration: true) }.to change { service.active }.from(false).to(true)
        end

        it 'activates service when manual_configuration is disabled' do
          expect { service.update!(manual_configuration: false) }.to change { service.active }.from(false).to(true)
        end
      end

      context 'when service is active' do
        before do
          service.active = true
        end

        it 'keeps service active when manual_configuration is enabled' do
          expect { service.update!(manual_configuration: true) }.not_to change { service.active }.from(true)
        end

        it 'keeps service active when manual_configuration is disabled' do
          expect { service.update!(manual_configuration: false) }.not_to change { service.active }.from(true)
        end
      end
    end
  end

  describe '#track_events after_commit callback' do
    before do
      allow(service).to receive(:prometheus_available?).and_return(true)
    end

    context "enabling manual_configuration" do
      it "tracks enable event" do
        service.update!(manual_configuration: false)
        service.update!(manual_configuration: true)

        expect_snowplow_event(category: 'cluster:services:prometheus', action: 'enabled_manual_prometheus')
      end

      it "tracks disable event" do
        service.update!(manual_configuration: true)
        service.update!(manual_configuration: false)

        expect_snowplow_event(category: 'cluster:services:prometheus', action: 'disabled_manual_prometheus')
      end
    end
  end

  describe '#editable?' do
    it 'is editable' do
      expect(service.editable?).to be(true)
    end

    context 'when cluster exists with prometheus installed' do
      let(:cluster) { create(:cluster, projects: [project]) }

      before do
        service.update!(manual_configuration: false)

        create(:clusters_applications_prometheus, :installed, cluster: cluster)
      end

      it 'remains editable' do
        expect(service.editable?).to be(true)
      end
    end
  end

  describe '#fields' do
    let(:expected_fields) do
      [
        {
          type: 'checkbox',
          name: 'manual_configuration',
          title: s_('PrometheusService|Active'),
          required: true
        },
        {
          type: 'text',
          name: 'api_url',
          title: 'API URL',
          placeholder: s_('PrometheusService|Prometheus API Base URL, like http://prometheus.example.com/'),
          required: true
        },
        {
          type: 'text',
          name: 'google_iap_audience_client_id',
          title: 'Google IAP Audience Client ID',
          placeholder: s_('PrometheusService|Client ID of the IAP secured resource (looks like IAP_CLIENT_ID.apps.googleusercontent.com)'),
          autocomplete: 'off',
          required: false
        },
        {
          type: 'textarea',
          name: 'google_iap_service_account_json',
          title: 'Google IAP Service Account JSON',
          placeholder: s_('PrometheusService|Contents of the credentials.json file of your service account, like: { "type": "service_account", "project_id": ... }'),
          required: false
        }
      ]
    end

    it 'returns fields' do
      expect(service.fields).to eq(expected_fields)
    end
  end
end
