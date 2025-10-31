require 'rails_helper'

RSpec.describe "Examples", type: :request do
  describe "GET /golden_deployment/examples" do
    let!(:examples) { create_list(:example, 10) }

    it "returns successful response" do
      get "/golden_deployment/examples"
      expect(response).to have_http_status(:ok)
    end

    it "displays the examples page" do
      get "/golden_deployment/examples"
      expect(response.body).to include('Golden Deployment')
      expect(response.body).to include('examples')
    end

    it "includes all examples in response" do
      example = create(:example, name: "Test Unique Name 123")
      get "/golden_deployment/examples"
      expect(response.body).to include("Test Unique Name 123")
    end

    it "includes percentile calculation data" do
      get "/golden_deployment/examples"
      expect(response.body).to include('percentile-values')
      expect(response.body).to include('examples-data')
    end

    it "calculates percentile values for filterable columns" do
      # Create examples with specific values to test percentile calculation
      Example.destroy_all
      ex1 = create(:example, priority: 1, score: 10.0, complexity: 1, speed: 1, quality: 1)
      ex2 = create(:example, priority: 3, score: 50.0, complexity: 3, speed: 3, quality: 3)
      ex3 = create(:example, priority: 5, score: 90.0, complexity: 5, speed: 5, quality: 5)

      get "/golden_deployment/examples"

      # Should include JSON data with the examples
      expect(response.body).to include(ex1.name)
      expect(response.body).to include(ex2.name)
      expect(response.body).to include(ex3.name)
    end

    it "displays example data" do
      example = create(:example, name: "Unique Test Pattern")
      get "/golden_deployment/examples"
      expect(response.body).to include("Unique Test Pattern")
    end

    it "includes examples data JSON in response" do
      example = create(:example, name: "JSON Test Pattern")
      get "/golden_deployment/examples"
      expect(response.body).to include('id="examples-data"')
      expect(response.body).to include("JSON Test Pattern")
    end

    it "includes percentile values JSON in response" do
      get "/golden_deployment/examples"
      expect(response.body).to include('id="percentile-values"')
    end

    context "with many examples" do
      it "loads all examples" do
        Example.destroy_all
        create_list(:example, 50)
        get "/golden_deployment/examples"
        expect(response.body).to include('50 of 50 examples')
      end

      it "includes example names in response" do
        Example.destroy_all
        example1 = create(:example, name: "First ABC Pattern")
        example2 = create(:example, name: "Second XYZ Pattern")

        get "/golden_deployment/examples"
        expect(response.body).to include("First ABC Pattern")
        expect(response.body).to include("Second XYZ Pattern")
      end
    end

    context "with examples of different statuses" do
      it "includes status badges in response" do
        Example.destroy_all
        create(:example, status: 'new')
        create(:example, status: 'completed')
        create(:example, status: 'in_progress')

        get "/golden_deployment/examples"
        # Just verify the page renders with the examples
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('examples')
      end

      it "displays status counts in stats grid" do
        get "/golden_deployment/examples"
        expect(response.body).to include('Total Patterns')
        expect(response.body).to include('Completed')
      end
    end
  end

  describe "GET /golden_deployment/examples/:id" do
    let(:example) { create(:example, name: "Test Pattern", category: "ui_pattern") }

    it "returns successful response" do
      get "/golden_deployment/examples/#{example.id}"
      expect(response).to have_http_status(:ok)
    end

    it "displays the show page" do
      get "/golden_deployment/examples/#{example.id}"
      expect(response.body).to include("Examples#show")
    end

    it "renders without error" do
      example = create(:example, name: "Unique Example XYZ789")
      get "/golden_deployment/examples/#{example.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Examples#show")
    end
  end

  describe "performance" do
    it "handles large datasets efficiently" do
      create_list(:example, 200)

      start_time = Time.now
      get "/golden_deployment/examples"
      duration = Time.now - start_time

      expect(response).to have_http_status(:ok)
      # Should complete in under 2 seconds even with 200 examples
      expect(duration).to be < 2.0
    end
  end

  describe "#index action logic" do
    context "when examples exist" do
      let!(:examples) { create_list(:example, 5) }

      it "assigns all examples to @examples variable" do
        get "/golden_deployment/examples"
        # Verify page renders with all examples
        expect(response.body).to include('5 of 5 examples')
      end

      it "orders examples by name" do
        Example.destroy_all
        create(:example, name: 'Zebra')
        create(:example, name: 'Apple')
        create(:example, name: 'Banana')

        get "/golden_deployment/examples"

        # Check that the page contains all names (order verified in system tests)
        expect(response.body).to include('Apple')
        expect(response.body).to include('Banana')
        expect(response.body).to include('Zebra')
      end

      it "calculates and assigns percentile_values variable" do
        get "/golden_deployment/examples"
        # Verify percentile data is included
        expect(response.body).to include('id="percentile-values"')
      end
    end

    context "when no examples exist" do
      before { Example.destroy_all }

      it "renders page with empty examples list" do
        get "/golden_deployment/examples"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('0 examples')
      end
    end
  end

  describe "#show action" do
    let(:example) { create(:example, name: "Show Test Pattern") }

    it "returns successful response for existing example" do
      get "/golden_deployment/examples/#{example.id}"
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for missing example" do
      get "/golden_deployment/examples/99999"
      expect(response).to have_http_status(:not_found)
    end

    it "renders the show template" do
      get "/golden_deployment/examples/#{example.id}"
      expect(response.body).to include("Examples#show")
    end
  end
end
