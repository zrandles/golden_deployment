# Helper methods for formatting and displaying example data
module ExamplesHelper
  # Status badge with color coding
  # new (blue), in_progress (yellow), completed (green), archived (gray)
  #
  # Usage:
  #   <%= status_badge(example.status) %>
  def status_badge(status)
    colors = {
      'new' => 'bg-blue-100 text-blue-700',
      'in_progress' => 'bg-yellow-100 text-yellow-700',
      'completed' => 'bg-green-100 text-green-700',
      'archived' => 'bg-gray-100 text-gray-700'
    }

    labels = {
      'new' => 'New',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      'archived' => 'Archived'
    }

    render_badge(status, colors, labels)
  end

  # Category badge with color coding
  # ui_pattern (purple), backend_pattern (green), data_pattern (blue), deployment_pattern (orange)
  #
  # Usage:
  #   <%= category_badge(example.category) %>
  def category_badge(category)
    colors = {
      'ui_pattern' => 'bg-purple-100 text-purple-700',
      'backend_pattern' => 'bg-green-100 text-green-700',
      'data_pattern' => 'bg-blue-100 text-blue-700',
      'deployment_pattern' => 'bg-orange-100 text-orange-700'
    }

    labels = {
      'ui_pattern' => 'UI',
      'backend_pattern' => 'Backend',
      'data_pattern' => 'Data',
      'deployment_pattern' => 'Deploy'
    }

    render_badge(category, colors, labels)
  end

  # Format numeric score with highlighting for high values
  # >= 90: green, >= 75: yellow, < 75: gray
  #
  # Usage:
  #   <%= format_score(example.score) %>
  def format_score(score)
    return empty_value_tag if score.nil?

    color_class = score_color_class(score)
    content_tag(:span, score.round(1), class: color_class)
  end

  # Format priority (1-5) with visual indicator
  # 5: critical (red), 4: high (orange), 3: medium (yellow), 2: low (blue), 1: minimal (gray)
  #
  # Usage:
  #   <%= format_priority(example.priority) %>
  def format_priority(priority)
    return empty_value_tag if priority.nil?

    colors = {
      5 => 'text-red-700 font-bold',
      4 => 'text-orange-700 font-semibold',
      3 => 'text-yellow-700',
      2 => 'text-blue-700',
      1 => 'text-gray-600'
    }

    color_class = colors[priority] || 'text-gray-600'
    content_tag(:span, priority, class: color_class)
  end

  # Highlight cell if value is in top percentile
  # Used for table cell highlighting
  #
  # Usage:
  #   <td class="<%= percentile_class(value, 'score', @percentiles) %>">
  def percentile_class(value, column, percentiles)
    return '' if missing_percentile_data?(value, column, percentiles)

    # Calculate percentile rank
    column_values = percentiles[column]
    percentile_rank = calculate_percentile(value.to_f, column_values)

    percentile_style_class(percentile_rank)
  end

  private

  # Shared badge rendering logic
  def render_badge(value, colors, labels)
    color_class = colors[value] || 'bg-gray-100 text-gray-700'
    label = labels[value] || value.to_s.titleize

    content_tag(:span, label, class: "px-2 py-1 text-xs rounded #{color_class}")
  end

  # Empty value placeholder
  def empty_value_tag
    content_tag(:span, '-', class: 'text-gray-400')
  end

  # Color class for score values
  def score_color_class(score)
    if score >= 90
      'text-green-700 font-bold'
    elsif score >= 75
      'text-yellow-700'
    else
      'text-gray-600'
    end
  end

  # Check if percentile data is available
  def missing_percentile_data?(value, column, percentiles)
    value.nil? || percentiles.nil? || percentiles[column].nil?
  end

  # Style class based on percentile rank
  def percentile_style_class(percentile_rank)
    if percentile_rank >= 95
      'bg-green-100 font-bold'
    elsif percentile_rank >= 90
      'bg-green-50'
    elsif percentile_rank >= 75
      'bg-yellow-50'
    else
      ''
    end
  end

  # Calculate percentile rank for a value
  def calculate_percentile(value, percentile_hash)
    # percentile_hash is { 0 => val, 5 => val, ..., 100 => val }
    # Find the highest percentile where value > threshold
    # Example: if value=93, and 90=>92, 95=>96, then value > 92 so percentile rank is 90
    result = 0
    percentile_hash.sort.reverse.each do |percentile, threshold_value|
      if value > threshold_value
        result = percentile
        break
      end
    end
    result
  end
end
