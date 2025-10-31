# API controller for managing examples via JSON endpoints
module Api
  class ExamplesController < ApplicationController
    # Skip CSRF for API requests (we use Bearer token auth instead)
    skip_before_action :verify_authenticity_token

    before_action :authenticate_api_token

    # GET /api/examples
    # Returns all examples as JSON
    #
    # Query params:
    #   status: Filter by status (new, in_progress, completed, archived)
    #   category: Filter by category (ui_pattern, backend_pattern, etc.)
    #   limit: Limit number of results
    #
    # Example:
    #   curl -H "Authorization: Bearer YOUR_TOKEN" https://24.199.71.69/golden_deployment/api/examples
    def index
      examples = Example.all

      # Apply filters
      status_param = params[:status]
      examples = examples.where(status: status_param) if status_param.present?

      category_param = params[:category]
      examples = examples.where(category: category_param) if category_param.present?

      limit_param = params[:limit]
      examples = examples.limit(limit_param.to_i) if limit_param.present?

      render json: {
        success: true,
        count: examples.count,
        examples: examples.map { |example| example_to_json(example) }
      }
    end

    # POST /api/examples/bulk_upsert
    # Creates or updates multiple examples in a single transaction
    #
    # Expected format:
    # {
    #   "examples": [
    #     {
    #       "name": "Example Name",            # Unique identifier for upsert
    #       "category": "ui_pattern",
    #       "status": "completed",
    #       "description": "...",
    #       "priority": 5,
    #       "score": 85,
    #       "complexity": 3,
    #       "speed": 4,
    #       "quality": 5
    #     }
    #   ]
    # }
    #
    # Returns:
    #   { success: true, created_count: X, updated_count: Y, created: [...], updated: [...] }
    #
    # Example:
    #   curl -X POST \
    #     -H "Authorization: Bearer YOUR_TOKEN" \
    #     -H "Content-Type: application/json" \
    #     -d '{"examples": [{"name": "Test", "status": "new", "category": "ui_pattern"}]}' \
    #     https://24.199.71.69/golden_deployment/api/examples/bulk_upsert
    def bulk_upsert
      examples_data = params.require(:examples)

      created_examples = []
      updated_examples = []
      errors = []

      # Use transaction for all-or-nothing operation
      ActiveRecord::Base.transaction do
        examples_data.each_with_index do |example_data, index|
          process_example_upsert(example_data, index, created_examples, updated_examples, errors)
        end
      end

      render_bulk_upsert_response(created_examples, updated_examples, errors)
    end

    private

    # Process a single example upsert (create or update)
    def process_example_upsert(example_data, index, created_examples, updated_examples, errors)
      name = example_data[:name]
      example = Example.find_by(name: name)
      params_hash = example_params(example_data)

      if example
        upsert_existing_example(example, params_hash, index, name, updated_examples, errors)
      else
        upsert_new_example(params_hash, index, name, created_examples, errors)
      end
    rescue StandardError => exception
      errors << { index: index, name: name, error: exception.message }
      raise ActiveRecord::Rollback
    end

    # Update existing example
    def upsert_existing_example(example, params_hash, index, name, updated_examples, errors)
      if example.update(params_hash)
        updated_examples << example
      else
        add_validation_error(errors, index, name, example.errors.full_messages)
        raise ActiveRecord::Rollback
      end
    end

    # Create new example
    def upsert_new_example(params_hash, index, name, created_examples, errors)
      example = Example.new(params_hash)
      if example.save
        created_examples << example
      else
        add_validation_error(errors, index, name, example.errors.full_messages)
        raise ActiveRecord::Rollback
      end
    end

    # Add validation error to errors array
    def add_validation_error(errors, index, name, error_messages)
      errors << { index: index, name: name, errors: error_messages }
    end

    # Render JSON response for bulk upsert
    def render_bulk_upsert_response(created_examples, updated_examples, errors)
      if errors.empty?
        render json: {
          success: true,
          created_count: created_examples.size,
          updated_count: updated_examples.size,
          created: created_examples.map { |example| { id: example.id, name: example.name } },
          updated: updated_examples.map { |example| { id: example.id, name: example.name } }
        }, status: :created
      else
        render json: {
          success: false,
          errors: errors
        }, status: :unprocessable_entity
      end
    end

    # Authenticate API requests with Bearer token
    # Token is stored in Rails credentials or ENV variable
    #
    # Setup:
    #   1. Generate token: SecureRandom.hex(32)
    #   2. Store in credentials: rails credentials:edit
    #      api:
    #        golden_deployment_token: "your-token-here"
    #   3. OR set ENV var: GOLDEN_DEPLOYMENT_API_TOKEN="your-token-here"
    def authenticate_api_token
      token = request.headers['Authorization']&.sub('Bearer ', '')

      # Get expected token from credentials or environment
      expected_token = Rails.application.credentials.dig(:api, :golden_deployment_token) ||
                      ENV['GOLDEN_DEPLOYMENT_API_TOKEN']

      unless expected_token.present?
        render json: { error: 'API not configured' }, status: :internal_server_error
        return
      end

      # Use secure comparison to prevent timing attacks
      unless ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected_token.to_s)
        render json: { error: 'Unauthorized - Invalid or missing API token' }, status: :unauthorized
      end
    end

    # Strong parameters for example attributes
    # Only allows explicitly permitted fields
    def example_params(data)
      {
        name: data['name'] || data[:name],
        category: data['category'] || data[:category],
        status: data['status'] || data[:status],
        description: data['description'] || data[:description],
        priority: data['priority'] || data[:priority],
        score: data['score'] || data[:score],
        complexity: data['complexity'] || data[:complexity],
        speed: data['speed'] || data[:speed],
        quality: data['quality'] || data[:quality]
      }.compact
    end

    # Convert example to JSON representation
    def example_to_json(example)
      {
        id: example.id,
        name: example.name,
        category: example.category,
        status: example.status,
        description: example.description,
        priority: example.priority,
        score: example.score,
        complexity: example.complexity,
        speed: example.speed,
        quality: example.quality,
        average_metrics: example.average_metrics,
        created_at: example.created_at,
        updated_at: example.updated_at
      }
    end
  end
end
