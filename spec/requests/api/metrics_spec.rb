require 'rails_helper'

RSpec.describe 'Api::Metrics', type: :request do
  describe 'GET /api/metrics' do
    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'returns successful response' do
        get '/golden_deployment/api/metrics'
        expect(response).to have_http_status(:ok)
      end

      it 'returns JSON response' do
        get '/golden_deployment/api/metrics'
        expect(response.content_type).to include('application/json')
      end

      it 'includes app_name in response' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json).to have_key('app_name')
      end

      it 'includes environment in response' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['environment']).to eq('development')
      end

      it 'includes timestamp in ISO8601 format' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['timestamp']).to match(/\d{4}-\d{2}-\d{2}T/)
      end

      it 'includes version in response' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json).to have_key('version')
      end

      it 'includes health metrics' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']).to be_a(Hash)
      end

      it 'includes revenue metrics key' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json).to have_key('revenue')
      end

      it 'includes users metrics key' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json).to have_key('users')
      end

      it 'includes engagement metrics key' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json).to have_key('engagement')
      end

      it 'includes custom metrics key' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json).to have_key('custom')
      end
    end

    describe 'health metrics' do
      it 'includes database health status' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']).to have_key('database')
        expect(json['health']['database']).to be_in([true, false])
      end

      it 'includes cache health status' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']).to have_key('cache')
        expect(json['health']['cache']).to be_in([true, false, nil])
      end

      it 'includes jobs health status' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']).to have_key('jobs')
        expect(json['health']['jobs']).to be_in([true, false, nil])
      end

      it 'includes storage health status' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']).to have_key('storage')
        expect(json['health']['storage']).to be_in([true, false, nil])
      end

      it 'database status is true when connected' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']['database']).to be true
      end
    end

    describe 'error handling' do
      it 'handles metric collection errors gracefully' do
        # Mock a failure in metric collection
        allow_any_instance_of(Api::MetricsController).to receive(:health_metrics).and_raise('Connection error')

        get '/golden_deployment/api/metrics'

        expect(response).to have_http_status(:internal_server_error)
        json = JSON.parse(response.body)
        expect(json).to have_key('error')
        expect(json['error']).to eq('Metrics collection failed')
      end

      it 'includes error message when collection fails' do
        allow_any_instance_of(Api::MetricsController).to receive(:health_metrics).and_raise('Test error')

        get '/golden_deployment/api/metrics'

        json = JSON.parse(response.body)
        expect(json['message']).to include('Test error')
      end

      it 'includes timestamp in error response' do
        allow_any_instance_of(Api::MetricsController).to receive(:health_metrics).and_raise('Error')

        get '/golden_deployment/api/metrics'

        json = JSON.parse(response.body)
        expect(json).to have_key('timestamp')
      end
    end

    describe 'user metrics' do
      context 'when User model exists' do
        it 'returns user metrics in response' do
          get '/golden_deployment/api/metrics'
          json = JSON.parse(response.body)
          # Since User might not exist in golden_deployment, users will be nil
          expect(json).to have_key('users')
        end
      end
    end

    describe 'custom metrics' do
      it 'returns custom metrics in response' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['custom']).to be_a(Hash)
      end

      it 'returns empty custom metrics by default' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['custom']).to eq({})
      end
    end

    describe 'app name detection' do
      it 'detects app name from Rails root basename' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['app_name']).to be_present
      end

      it 'returns consistent app name' do
        get '/golden_deployment/api/metrics'
        json1 = JSON.parse(response.body)

        get '/golden_deployment/api/metrics'
        json2 = JSON.parse(response.body)

        expect(json1['app_name']).to eq(json2['app_name'])
      end
    end

    describe 'version detection' do
      it 'returns a version string' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['version']).to be_present
        expect(json['version']).to be_a(String)
      end
    end

    describe 'database health check' do
      it 'verifies database connection' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']['database']).to be true
      end

      it 'detects database disconnection' do
        allow_any_instance_of(Api::MetricsController).to receive(:database_connected?).and_return(false)
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']['database']).to be false
      end
    end

    describe 'cache health check' do
      it 'checks cache connectivity' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        expect(json['health']['cache']).to be_in([true, false])
      end
    end

    describe 'jobs health check' do
      it 'checks job system health' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        # Should be true, false, or nil depending on setup
        expect(json['health']['jobs']).to be_in([true, false, nil])
      end
    end

    describe 'storage health check' do
      it 'checks storage connectivity' do
        get '/golden_deployment/api/metrics'
        json = JSON.parse(response.body)
        # Should be true, false, or nil depending on setup
        expect(json['health']['storage']).to be_in([true, false, nil])
      end
    end
  end

  describe 'production environment' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    end

    context 'without token' do
      it 'returns unauthorized if token is configured' do
        # Mock token configuration
        allow(Rails.application.credentials).to receive(:dig).with(:metrics_api_token).and_return('test-token')

        get '/golden_deployment/api/metrics'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
      end
    end

    context 'with valid token' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:metrics_api_token).and_return('test-token')
      end

      it 'allows access with bearer token' do
        get '/golden_deployment/api/metrics', headers: { 'Authorization' => 'Bearer test-token' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to have_key('app_name')
      end

      it 'rejects request with invalid token' do
        get '/golden_deployment/api/metrics', headers: { 'Authorization' => 'Bearer wrong-token' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects request with malformed authorization header' do
        get '/golden_deployment/api/metrics', headers: { 'Authorization' => 'InvalidFormat test-token' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when no token configured' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:metrics_api_token).and_return(nil)
      end

      it 'allows access without token (backwards compatibility)' do
        get '/golden_deployment/api/metrics'

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
