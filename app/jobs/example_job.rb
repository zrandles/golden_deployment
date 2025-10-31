# Background Job Pattern with Solid Queue (Rails 8)
#
# Solid Queue is Rails 8's built-in job processor (no Redis/Sidekiq needed).
# It stores jobs in the database and processes them asynchronously.
#
# Benefits:
# - No additional infrastructure (Redis)
# - Reliable job persistence
# - Built-in retry logic
# - Recurring job support
#
# Pattern from territory_game and app_monitor apps
class ExampleJob < ApplicationJob
  queue_as :default

  # Retry failed jobs up to 5 times with exponential backoff
  retry_on StandardError, wait: ->(executions) { executions * 5 }, attempts: 5

  # Example: Process a single example (one-time job)
  #
  # Enqueue from anywhere:
  #   ExampleJob.perform_later(example_id)
  #
  # Or perform immediately (for testing):
  #   ExampleJob.perform_now(example_id)
  def perform(example_id)
    example = Example.find(example_id)
    logger = Rails.logger
    example_name = example.name

    logger.info "Processing example: #{example_name}"

    # Example operation: Recalculate average metrics
    if example.complexity.present? && example.speed.present? && example.quality.present?
      # The model already has average_metrics method, but this shows how
      # a job might update data based on complex calculations
      avg = (example.complexity + example.speed + example.quality) / 3.0

      # Log the calculation
      logger.info "Calculated average metrics: #{avg}"
    end

    logger.info "Finished processing example: #{example_name}"
  end
end

# Example: Recurring Job for Daily Statistics
#
# To make this recurring, add to config/recurring.yml:
#
# example_daily_stats:
#   class: ExampleDailyStatsJob
#   schedule: every day at 6am
#   args: []
#
# Pattern: Recurring jobs are great for cleanup, statistics, notifications
class ExampleDailyStatsJob < ApplicationJob
  queue_as :default

  # Runs daily to calculate and log statistics
  def perform
    logger = Rails.logger
    logger.info "=== Daily Example Statistics ==="

    stats = ExampleService.calculate_statistics

    logger.info "Total examples: #{stats[:total_count]}"
    logger.info "Completed: #{stats[:completed_count]}"
    logger.info "In progress: #{stats[:in_progress_count]}"
    logger.info "Completion rate: #{(stats[:completion_rate] * 100).round(1)}%"
    logger.info "Average score: #{stats[:average_score]}"

    # Could also:
    # - Send email digest
    # - Update cached statistics
    # - Generate reports
    # - Archive old data

    logger.info "=== End Daily Stats ==="
  end
end

# Example: Bulk Processing Job
#
# Pattern: Process many records in batches to avoid memory issues
#
# Enqueue:
#   ExampleBulkProcessJob.perform_later(example_ids)
class ExampleBulkProcessJob < ApplicationJob
  queue_as :default

  def perform(example_ids)
    logger = Rails.logger
    example_count = example_ids.length

    logger.info "Bulk processing #{example_count} examples"

    # Process in batches of 50
    example_ids.in_groups_of(50, false) do |batch_ids|
      batch = Example.where(id: batch_ids)

      batch.each do |example|
        # Do something with each example
        logger.debug "Processing: #{example.name}"

        # Example: Update score based on some calculation
        # example.update(score: calculate_new_score(example))
      end

      # Small delay between batches to avoid overwhelming the system
      sleep(0.1)
    end

    logger.info "Finished bulk processing"
  end
end

# Example: Job with Error Handling
#
# Pattern: Graceful error handling with custom retry logic
class ExampleWithErrorHandlingJob < ApplicationJob
  queue_as :default

  # Custom retry logic for specific errors
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 3
  retry_on StandardError, wait: :exponentially_longer_with_jitter, attempts: 5

  # Discard job if specific error occurs (don't retry)
  discard_on ActiveJob::DeserializationError

  def perform(example_id)
    example = Example.find(example_id)

    begin
      # Do something that might fail
      process_example(example)
    rescue SomeCustomError => error
      # Log error but don't fail the job
      Rails.logger.error "Error processing example #{example_id}: #{error.message}"
      # Could also: send notification, record error, etc.
    end
  end

  private

  def process_example(example)
    # Custom processing logic here
    Rails.logger.info "Processing: #{example.name}"
  end
end
