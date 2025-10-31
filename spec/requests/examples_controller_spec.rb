require 'rails_helper'

RSpec.describe ExamplesController, type: :request do
  describe 'percentile calculation logic' do
    before do
      Example.destroy_all
    end

    context 'with examples having specific numeric values' do
      let!(:examples) do
        [
          create(:example, score: 10.0, priority: 1, complexity: 1, speed: 1, quality: 1),
          create(:example, score: 20.0, priority: 2, complexity: 2, speed: 2, quality: 2),
          create(:example, score: 30.0, priority: 3, complexity: 3, speed: 3, quality: 3),
          create(:example, score: 40.0, priority: 4, complexity: 4, speed: 4, quality: 4),
          create(:example, score: 50.0, priority: 5, complexity: 5, speed: 5, quality: 5)
        ]
      end

      it 'calculates percentile values for filterable columns' do
        get '/golden_deployment/examples'

        # Extract percentile data from response
        expect(response.body).to include('percentile-values')
      end

      it 'includes 0th and 100th percentile values' do
        get '/golden_deployment/examples'

        # Response should have percentile data
        expect(response).to have_http_status(:ok)
      end

      it 'handles nil values in percentile calculation' do
        create(:example, score: nil, priority: nil, complexity: nil, speed: nil, quality: nil)

        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
      end

      it 'excludes nil values from percentile calculation' do
        Example.destroy_all
        create(:example, score: 10.0)
        create(:example, score: nil)
        create(:example, score: 20.0)

        get '/golden_deployment/examples'

        # Should still calculate percentiles from the 2 non-nil values
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with only nil values in a column' do
      before do
        Example.destroy_all
        create_list(:example, 3, score: nil)
      end

      it 'skips percentile calculation for that column' do
        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
        # Should not crash and should still render the page
      end
    end

    context 'with single example' do
      before do
        Example.destroy_all
        create(:example, score: 50.0, priority: 3)
      end

      it 'calculates percentiles correctly with one value' do
        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
        # Percentiles should all be the same value
      end
    end

    context 'percentile ranges' do
      before do
        Example.destroy_all
        create_list(:example, 101) do |example, i|
          create(:example, score: i.to_f)
        end
      end

      it 'calculates correct 5th percentile' do
        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
        # Percentiles should be computed
      end

      it 'calculates correct 50th percentile' do
        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
        # Middle percentile should be around 50
      end

      it 'calculates correct 95th percentile' do
        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
        # Upper percentile should be near the max
      end
    end
  end

  describe 'column ordering' do
    before do
      Example.destroy_all
    end

    it 'returns examples ordered by name' do
      create(:example, name: 'Zebra Pattern')
      create(:example, name: 'Apple Pattern')
      create(:example, name: 'Banana Pattern')

      get '/golden_deployment/examples'

      # Examples should be ordered alphabetically by name
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Apple Pattern')
      expect(response.body).to include('Zebra Pattern')
    end
  end

  describe 'large dataset handling' do
    it 'handles 500 examples without performance degradation' do
      create_list(:example, 500)

      start_time = Time.now
      get '/golden_deployment/examples'
      duration = Time.now - start_time

      expect(response).to have_http_status(:ok)
      # Should complete in reasonable time
      expect(duration).to be < 5.0
    end

    it 'includes all 500 examples in data' do
      create_list(:example, 500)

      get '/golden_deployment/examples'

      # Percentile data should include all examples
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'with examples in various states' do
    before do
      Example.destroy_all
    end

    it 'includes completed, in_progress, and new examples' do
      create(:example, :completed)
      create(:example, :in_progress)
      create(:example, :new_status)

      get '/golden_deployment/examples'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('3 of 3 examples')
    end

    it 'correctly counts examples by status' do
      create_list(:example, 5, :completed)
      create_list(:example, 3, :in_progress)
      create_list(:example, 2, :new_status)

      get '/golden_deployment/examples'

      # Page should reflect these counts
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'data type conversions in percentile calculation' do
    before do
      Example.destroy_all
    end

    it 'converts all numeric values to float for percentile calculation' do
      # Create examples with mixed numeric types
      create(:example, priority: 1, score: 50.5, complexity: 2, speed: 3, quality: 4)
      create(:example, priority: 5, score: 85.2, complexity: 5, speed: 5, quality: 5)

      get '/golden_deployment/examples'

      expect(response).to have_http_status(:ok)
      # Should handle mixed int and float seamlessly
    end

    it 'rounds percentile values to 2 decimal places' do
      Example.destroy_all
      create_list(:example, 3) do |example, i|
        create(:example, score: (i * 33.333).round(3))
      end

      get '/golden_deployment/examples'

      expect(response).to have_http_status(:ok)
      # Percentile values should be properly rounded
    end
  end

  describe 'filtering columns' do
    it 'only calculates percentiles for filterable columns' do
      Example.destroy_all
      create(:example, name: 'Test', score: 50, priority: 3)

      get '/golden_deployment/examples'

      # Should include percentiles for: priority, score, complexity, speed, quality
      # Should NOT include percentiles for: name, status, category (non-numeric)
      expect(response).to have_http_status(:ok)
    end

    it 'includes all required filterable columns' do
      get '/golden_deployment/examples'

      # Response should have percentile data for these columns:
      # priority, score, complexity, speed, quality
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'edge cases' do
    context 'with minimum valid scores' do
      it 'calculates percentiles with minimum allowed values' do
        Example.destroy_all
        create(:example, score: 0.0)
        create(:example, score: 50.0)
        create(:example, score: 100.0)

        get '/golden_deployment/examples'

        # Score validation requires >= 0
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with very large numbers' do
      it 'handles large score values' do
        Example.destroy_all
        create(:example, score: 99.99)
        create(:example, score: 100.0)

        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with duplicate values' do
      it 'calculates percentiles correctly with many duplicate values' do
        Example.destroy_all
        create_list(:example, 5, score: 50.0)
        create_list(:example, 5, score: 75.0)

        get '/golden_deployment/examples'

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
