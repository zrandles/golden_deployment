require 'rails_helper'

RSpec.describe 'Api::Examples', type: :request do
  let(:valid_token) { 'test-api-token-12345' }
  let(:invalid_token) { 'wrong-token' }
  let(:auth_headers) { { 'Authorization' => "Bearer #{valid_token}" } }
  let(:invalid_auth_headers) { { 'Authorization' => "Bearer #{invalid_token}" } }

  before do
    # Set API token in environment for tests
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GOLDEN_DEPLOYMENT_API_TOKEN').and_return(valid_token)
  end

  describe 'GET /api/examples' do
    context 'with valid authentication' do
      let!(:examples) do
        [
          create(:example, name: 'Example 1', status: :new, category: :ui_pattern),
          create(:example, name: 'Example 2', status: :completed, category: :backend_pattern),
          create(:example, name: 'Example 3', status: :new, category: :data_pattern)
        ]
      end

      it 'returns all examples' do
        get '/golden_deployment/api/examples', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['count']).to eq(3)
        expect(json['examples'].size).to eq(3)
      end

      it 'includes all example fields' do
        get '/golden_deployment/api/examples', headers: auth_headers

        json = JSON.parse(response.body)
        example_json = json['examples'].first

        expect(example_json).to include(
          'id', 'name', 'category', 'status', 'description',
          'priority', 'score', 'complexity', 'speed', 'quality',
          'average_metrics', 'created_at', 'updated_at'
        )
      end

      it 'filters by status' do
        get '/golden_deployment/api/examples?status=new', headers: auth_headers

        json = JSON.parse(response.body)
        expect(json['count']).to eq(2)
        expect(json['examples'].map { |e| e['status'] }).to all(eq('new'))
      end

      it 'filters by category' do
        get '/golden_deployment/api/examples?category=ui_pattern', headers: auth_headers

        json = JSON.parse(response.body)
        expect(json['count']).to eq(1)
        expect(json['examples'].first['category']).to eq('ui_pattern')
      end

      it 'limits results' do
        get '/golden_deployment/api/examples?limit=2', headers: auth_headers

        json = JSON.parse(response.body)
        expect(json['examples'].size).to eq(2)
      end

      it 'combines filters' do
        get '/golden_deployment/api/examples?status=new&category=ui_pattern', headers: auth_headers

        json = JSON.parse(response.body)
        expect(json['count']).to eq(1)
        expect(json['examples'].first['name']).to eq('Example 1')
      end

      it 'returns empty array when no examples match filters' do
        get '/golden_deployment/api/examples?status=archived', headers: auth_headers

        json = JSON.parse(response.body)
        expect(json['count']).to eq(0)
        expect(json['examples']).to eq([])
      end
    end

    context 'without authentication' do
      it 'returns unauthorized error when no token provided' do
        get '/golden_deployment/api/examples'

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Unauthorized')
      end

      it 'returns unauthorized error with invalid token' do
        get '/golden_deployment/api/examples', headers: invalid_auth_headers

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Unauthorized')
      end
    end

    context 'when API is not configured' do
      before do
        allow(ENV).to receive(:[]).with('GOLDEN_DEPLOYMENT_API_TOKEN').and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with(:api, :golden_deployment_token).and_return(nil)
      end

      it 'returns internal server error' do
        get '/golden_deployment/api/examples', headers: auth_headers

        expect(response).to have_http_status(:internal_server_error)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('API not configured')
      end
    end
  end

  describe 'POST /api/examples/bulk_upsert' do
    context 'with valid authentication' do
      context 'creating new examples' do
        let(:new_examples_data) do
          {
            examples: [
              {
                name: 'New Example 1',
                category: 'ui_pattern',
                status: 'new',
                description: 'Test description',
                priority: 3,
                score: 75,
                complexity: 2,
                speed: 4,
                quality: 3
              },
              {
                name: 'New Example 2',
                category: 'backend_pattern',
                status: 'completed',
                priority: 5
              }
            ]
          }
        end

        it 'creates all examples successfully' do
          expect {
            post '/golden_deployment/api/examples/bulk_upsert',
                 params: new_examples_data.to_json,
                 headers: auth_headers.merge('Content-Type' => 'application/json')
          }.to change(Example, :count).by(2)

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['created_count']).to eq(2)
          expect(json['updated_count']).to eq(0)
        end

        it 'returns created example IDs and names' do
          post '/golden_deployment/api/examples/bulk_upsert',
               params: new_examples_data.to_json,
               headers: auth_headers.merge('Content-Type' => 'application/json')

          json = JSON.parse(response.body)
          expect(json['created']).to be_an(Array)
          expect(json['created'].first).to include('id', 'name')
          expect(json['created'].map { |e| e['name'] }).to match_array(['New Example 1', 'New Example 2'])
        end

        it 'creates examples with all provided attributes' do
          post '/golden_deployment/api/examples/bulk_upsert',
               params: new_examples_data.to_json,
               headers: auth_headers.merge('Content-Type' => 'application/json')

          example = Example.find_by(name: 'New Example 1')
          expect(example.category).to eq('ui_pattern')
          expect(example.status).to eq('new')
          expect(example.description).to eq('Test description')
          expect(example.priority).to eq(3)
          expect(example.score).to eq(75)
          expect(example.complexity).to eq(2)
          expect(example.speed).to eq(4)
          expect(example.quality).to eq(3)
        end
      end

      context 'updating existing examples' do
        let!(:existing_example) { create(:example, name: 'Existing Example', score: 50, priority: 2) }

        let(:update_data) do
          {
            examples: [
              {
                name: 'Existing Example',
                score: 90,
                priority: 5,
                status: 'completed'
              }
            ]
          }
        end

        it 'updates existing example' do
          expect {
            post '/golden_deployment/api/examples/bulk_upsert',
                 params: update_data.to_json,
                 headers: auth_headers.merge('Content-Type' => 'application/json')
          }.not_to change(Example, :count)

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['created_count']).to eq(0)
          expect(json['updated_count']).to eq(1)
        end

        it 'updates example attributes' do
          post '/golden_deployment/api/examples/bulk_upsert',
               params: update_data.to_json,
               headers: auth_headers.merge('Content-Type' => 'application/json')

          existing_example.reload
          expect(existing_example.score).to eq(90)
          expect(existing_example.priority).to eq(5)
          expect(existing_example.status).to eq('completed')
        end

        it 'returns updated example IDs and names' do
          post '/golden_deployment/api/examples/bulk_upsert',
               params: update_data.to_json,
               headers: auth_headers.merge('Content-Type' => 'application/json')

          json = JSON.parse(response.body)
          expect(json['updated']).to be_an(Array)
          expect(json['updated'].first['name']).to eq('Existing Example')
          expect(json['updated'].first['id']).to eq(existing_example.id)
        end
      end

      context 'mixing creates and updates' do
        let!(:existing) { create(:example, name: 'Existing', priority: 1) }

        let(:mixed_data) do
          {
            examples: [
              { name: 'Existing', priority: 5 },
              { name: 'New Example', priority: 3, category: 'ui_pattern', status: 'new' }
            ]
          }
        end

        it 'handles both creates and updates in one request' do
          expect {
            post '/golden_deployment/api/examples/bulk_upsert',
                 params: mixed_data.to_json,
                 headers: auth_headers.merge('Content-Type' => 'application/json')
          }.to change(Example, :count).by(1)

          json = JSON.parse(response.body)
          expect(json['created_count']).to eq(1)
          expect(json['updated_count']).to eq(1)
        end
      end

      context 'with validation errors' do
        let(:invalid_data) do
          {
            examples: [
              { name: 'Good Example', category: 'ui_pattern', status: 'new' },
              { name: '', category: 'ui_pattern' }, # Invalid: blank name
              { name: 'Another Good', category: 'backend_pattern', status: 'new' }
            ]
          }
        end

        it 'rolls back entire transaction on validation error' do
          expect {
            post '/golden_deployment/api/examples/bulk_upsert',
                 params: invalid_data.to_json,
                 headers: auth_headers.merge('Content-Type' => 'application/json')
          }.not_to change(Example, :count)
        end

        it 'returns error details' do
          post '/golden_deployment/api/examples/bulk_upsert',
               params: invalid_data.to_json,
               headers: auth_headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['errors']).to be_an(Array)
          expect(json['errors'].first).to include('index', 'errors')
        end
      end

      context 'with missing required parameter' do
        it 'returns error when examples parameter is missing' do
          post '/golden_deployment/api/examples/bulk_upsert',
               params: {}.to_json,
               headers: auth_headers.merge('Content-Type' => 'application/json')

          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'without authentication' do
      let(:examples_data) do
        {
          examples: [
            { name: 'Test', category: 'ui_pattern', status: 'new' }
          ]
        }
      end

      it 'returns unauthorized error when no token provided' do
        post '/golden_deployment/api/examples/bulk_upsert',
             params: examples_data.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized error with invalid token' do
        post '/golden_deployment/api/examples/bulk_upsert',
             params: examples_data.to_json,
             headers: invalid_auth_headers.merge('Content-Type' => 'application/json')

        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not create examples without valid token' do
        expect {
          post '/golden_deployment/api/examples/bulk_upsert',
               params: examples_data.to_json,
               headers: { 'Content-Type' => 'application/json' }
        }.not_to change(Example, :count)
      end
    end
  end
end
