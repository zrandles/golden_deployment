# Service Object Pattern
#
# Service objects encapsulate business logic that doesn't naturally belong in a model or controller.
# They're particularly useful for:
# - Complex operations involving multiple models
# - External API interactions
# - Data transformations
# - Operations with multiple steps
#
# Benefits:
# - Keeps controllers thin
# - Makes business logic testable
# - Single Responsibility Principle
# - Clear interface
#
# Pattern from app_monitor and idea_tracker apps
class ExampleService
  # Calculate statistics for all examples
  #
  # Returns a hash with aggregated metrics
  #
  # Usage:
  #   stats = ExampleService.calculate_statistics
  #   stats[:total_count]  # => 50
  #   stats[:completion_rate]  # => 0.65
  def self.calculate_statistics
    total = Example.count
    completed = Example.where(status: 'completed').count
    in_progress = Example.where(status: 'in_progress').count
    new_examples = Example.where(status: 'new').count

    {
      total_count: total,
      completed_count: completed,
      in_progress_count: in_progress,
      new_count: new_examples,
      completion_rate: total > 0 ? completed.to_f / total : 0,
      average_score: Example.average(:score)&.round(2),
      average_priority: Example.average(:priority)&.round(2)
    }
  end

  # Find top performing examples by score
  #
  # @param limit [Integer] Number of examples to return (default: 10)
  # @param min_score [Integer] Minimum score threshold (default: 75)
  # @return [ActiveRecord::Relation]
  #
  # Usage:
  #   top_examples = ExampleService.top_performers(limit: 5, min_score: 90)
  def self.top_performers(limit: 10, min_score: 75)
    Example.where('score >= ?', min_score)
           .where(status: 'completed')
           .order(score: :desc)
           .limit(limit)
  end

  # Find examples that need attention
  # (high priority but not completed)
  #
  # @return [ActiveRecord::Relation]
  #
  # Usage:
  #   urgent = ExampleService.needs_attention
  def self.needs_attention
    Example.where(priority: [4, 5])
           .where.not(status: 'completed')
           .order(priority: :desc, created_at: :asc)
  end

  # Bulk update status for multiple examples
  #
  # @param example_ids [Array<Integer>] IDs of examples to update
  # @param new_status [String] New status value
  # @return [Hash] Result with success boolean and counts
  #
  # Usage:
  #   result = ExampleService.bulk_update_status([1, 2, 3], 'completed')
  #   result[:success]  # => true
  #   result[:updated_count]  # => 3
  def self.bulk_update_status(example_ids, new_status)
    return { success: false, error: 'Invalid status' } unless Example::STATUSES.include?(new_status)

    updated_count = 0

    ActiveRecord::Base.transaction do
      example_ids.each do |id|
        example = Example.find_by(id: id)
        next unless example

        if example.update(status: new_status)
          updated_count += 1
        else
          raise ActiveRecord::Rollback
        end
      end
    end

    { success: true, updated_count: updated_count }
  rescue StandardError => error
    { success: false, error: error.message }
  end

  # Calculate percentile rank for a given score
  #
  # @param score [Float] Score to rank
  # @param column [Symbol] Column to calculate percentile for (default: :score)
  # @return [Integer] Percentile rank (0-100)
  #
  # Usage:
  #   rank = ExampleService.calculate_percentile_rank(85.0, :score)
  #   # => 75  (85.0 is in the 75th percentile)
  def self.calculate_percentile_rank(score, column = :score)
    all_scores = Example.where.not(column => nil).pluck(column).sort

    return 0 if all_scores.empty?

    count_below = all_scores.count { |value| value <= score }
    ((count_below.to_f / all_scores.length) * 100).round
  end

  # Example of caching expensive operation
  #
  # Rails.cache.fetch caches the result for 1 hour
  # Cleared when data changes
  #
  # Usage:
  #   leaderboard = ExampleService.cached_leaderboard
  def self.cached_leaderboard
    Rails.cache.fetch('example_leaderboard', expires_in: 1.hour) do
      top_performers(limit: 20)
    end
  end

  # Clear all cached data (call after bulk updates)
  #
  # Usage:
  #   ExampleService.clear_cache
  def self.clear_cache
    Rails.cache.delete('example_leaderboard')
  end
end
