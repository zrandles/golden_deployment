# Business Metrics API for App Monitor Integration
#
# This controller provides a standardized metrics endpoint that app_monitor
# can query to display business metrics alongside operational metrics.
#
# Override the private methods in your app to provide real metrics.
# The base implementation provides sensible defaults and examples.
#
class Api::MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_metrics_token, if: :token_required?

  def show
    current_time = Time.current.iso8601

    render json: {
      app_name: detect_app_name,
      environment: Rails.env,
      timestamp: current_time,
      version: app_version,

      # Business metrics
      revenue: revenue_metrics,
      users: user_metrics,
      engagement: engagement_metrics,

      # Operational health (useful for app_monitor)
      health: health_metrics,

      # App-specific custom metrics
      custom: custom_metrics
    }
  rescue StandardError => error
    render json: {
      error: "Metrics collection failed",
      message: error.message,
      timestamp: Time.current.iso8601
    }, status: :internal_server_error
  end

  private

  # Override this method to implement revenue tracking
  # Return nil for apps without revenue
  def revenue_metrics
    # Example implementation for apps with payments
    # if defined?(Payment)
    #   {
    #     mrr: Payment.active.monthly.sum(:amount),
    #     arr: Payment.active.monthly.sum(:amount) * 12,
    #     total_revenue: Payment.completed.sum(:amount),
    #     currency: "USD",
    #     paying_customers: Payment.active.distinct.count(:user_id)
    #   }
    # else
    #   nil
    # end
    nil  # Default: no revenue tracking
  end

  # Override this method based on your User/Account model
  def user_metrics
    if defined?(User)
      user_activity_metrics(User, 'last_sign_in_at')
    elsif defined?(Account)
      user_activity_metrics(Account, 'updated_at')
    else
      nil  # No user tracking
    end
  end

  # Override this method to define your app's key engagement metric
  # This should be THE metric that matters most for this specific app
  def engagement_metrics
    # Example implementations:
    #
    # For a SaaS app:
    # {
    #   metric_name: "Weekly Active Users",
    #   metric_value: User.where("last_sign_in_at > ?", 7.days.ago).count,
    #   metric_unit: "users",
    #   trend: calculate_trend_percentage
    # }
    #
    # For an e-commerce app:
    # {
    #   metric_name: "Conversion Rate",
    #   metric_value: 12.5,
    #   metric_unit: "%",
    #   details: {
    #     visitors: 1000,
    #     purchases: 125
    #   }
    # }
    #
    # For a game:
    # {
    #   metric_name: "Daily Games Played",
    #   metric_value: Game.where("created_at > ?", 1.day.ago).count,
    #   metric_unit: "games"
    # }

    nil  # Default: no engagement tracking
  end

  # Override for app-specific custom metrics
  # Use this for metrics unique to your app's domain
  def custom_metrics
    # Example for an e-commerce app:
    # {
    #   products: {
    #     total: Product.count,
    #     active: Product.active.count,
    #     out_of_stock: Product.out_of_stock.count
    #   },
    #   orders: {
    #     today: Order.where("created_at > ?", 1.day.ago).count,
    #     pending: Order.pending.count,
    #     average_value: Order.completed.average(:total)&.round(2)
    #   }
    # }

    {}  # Default: no custom metrics
  end

  # Basic health checks - usually don't need to override
  def health_metrics
    {
      database: database_connected?,
      cache: cache_connected?,
      jobs: jobs_healthy?,
      storage: storage_connected?
    }
  end

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue
    false
  end

  def cache_connected?
    cache = Rails.cache
    cache.write("health_check", "ok", expires_in: 1.second)
    cache.read("health_check") == "ok"
  rescue
    false
  end

  def jobs_healthy?
    check_service_health(SolidQueue::Job)
  end

  def storage_connected?
    check_service_health(ActiveStorage::Blob)
  end

  def app_version
    rails_root = Rails.root
    version_file_path = rails_root.join("VERSION")
    git_ref_path = rails_root.join(".git/refs/heads/main")

    if File.exist?(version_file_path)
      File.read(version_file_path).strip
    elsif File.exist?(git_ref_path)
      File.read(git_ref_path).strip[0..7]
    else
      "unknown"
    end
  end

  # Security: Override these methods to add token authentication
  def token_required?
    Rails.env.production?
  end

  def verify_metrics_token
    # Simple bearer token auth - set METRICS_API_TOKEN in credentials
    # In production, app_monitor will need to send this token
    expected_token = Rails.application.credentials.dig(:metrics_api_token)

    # If no token configured, allow access (backwards compatibility)
    return true unless expected_token.present?

    # Check Authorization header
    provided_token = request.headers["Authorization"]&.gsub("Bearer ", "")

    unless provided_token == expected_token
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def detect_app_name
    # Try multiple methods to detect the app name
    rails_root = Rails.root
    root_basename = rails_root.basename.to_s

    # 1. Check Rails root directory name
    return root_basename if root_basename != "current"

    # 2. For production deployments, check parent directory
    if production_deployment?
      return rails_root.parent.parent.basename.to_s
    end

    # 3. Fall back to module name
    Rails.application.class.module_parent_name.underscore
  end

  # Helper methods to reduce duplication

  # Build user/account activity metrics
  def user_activity_metrics(model, activity_column)
    one_week_ago = 7.days.ago
    one_month_ago = 30.days.ago

    # Use Arel to safely construct queries with dynamic column names
    # This prevents SQL injection by using parameterized queries
    {
      total: model.count,
      active_7d: model.where(model.arel_table[activity_column].gt(one_week_ago)).count,
      active_30d: model.where(model.arel_table[activity_column].gt(one_month_ago)).count,
      new_this_week: model.where("created_at > ?", one_week_ago).count,
      new_this_month: model.where("created_at > ?", one_month_ago).count
    }
  end

  # Check if service/model can be queried
  def check_service_health(model_class)
    return nil unless defined?(model_class)

    model_class.count >= 0  # Just checking we can query
    true
  rescue
    false
  end

  # Check if this is a production deployment structure
  def production_deployment?
    rails_root = Rails.root
    rails_root.to_s.include?("/home/zac/") && rails_root.basename.to_s == "current"
  end
end