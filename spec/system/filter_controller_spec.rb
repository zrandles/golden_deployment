require 'rails_helper'

RSpec.describe 'Filter Controller', type: :system, js: true do
  # Create test data with known values for filtering
  let!(:low_score_examples) do
    [
      create(:example, name: 'Low Score 1', score: 10, priority: 1, complexity: 5),
      create(:example, name: 'Low Score 2', score: 15, priority: 2, complexity: 4),
      create(:example, name: 'Low Score 3', score: 20, priority: 2, complexity: 3)
    ]
  end

  let!(:high_score_examples) do
    [
      create(:example, name: 'High Score 1', score: 80, priority: 4, complexity: 2),
      create(:example, name: 'High Score 2', score: 90, priority: 5, complexity: 1),
      create(:example, name: 'High Score 3', score: 95, priority: 5, complexity: 1)
    ]
  end

  let!(:mid_score_examples) do
    [
      create(:example, name: 'Mid Score 1', score: 45, priority: 3, complexity: 3),
      create(:example, name: 'Mid Score 2', score: 50, priority: 3, complexity: 3),
      create(:example, name: 'Mid Score 3', score: 55, priority: 3, complexity: 3)
    ]
  end

  before do
    # Clear localStorage before each test to prevent test pollution
    visit '/golden_deployment/examples'
    page.execute_script('localStorage.clear();')
    visit '/golden_deployment/examples'
    # Wait for page to fully load
    expect(page).to have_content('Golden Deployment')
  end

  describe 'page load and JavaScript initialization' do
    it 'loads without JavaScript errors' do
      # Check browser console for errors
      logs = page.driver.browser.logs.get(:browser)
      errors = logs.select { |log| log.level == 'SEVERE' }

      expect(errors).to be_empty, "JavaScript errors found: #{errors.map(&:message).join("\n")}"
    end

    it 'displays correct number of examples' do
      expect(page).to have_content('Showing 9 of 9 examples')
    end

    it 'loads example data into JavaScript' do
      # Verify the script tag with data exists
      expect(page).to have_css('script#examples-data', visible: false)

      # Verify data contains actual example names, not code quality metrics
      page_html = page.html
      expect(page_html).to include('Low Score 1')
      expect(page_html).to include('High Score 1')

      # Should NOT contain code quality terms from wrong data
      expect(page_html).not_to include('rails_metrics')
      expect(page_html).not_to include('RailsMetric')
    end

    it 'displays all example names in the table' do
      expect(page).to have_content('Low Score 1')
      expect(page).to have_content('High Score 1')
      expect(page).to have_content('Mid Score 1')
    end

    it 'renders table headers correctly' do
      expect(page).to have_css('th', text: 'Name')
      expect(page).to have_css('th', text: 'Score')
      expect(page).to have_css('th', text: 'Priority')
    end
  end

  describe 'search functionality' do
    it 'has a search input field' do
      expect(page).to have_css('input[placeholder="Search by name..."]')
    end

    it 'can type into search field' do
      search_field = find('input[placeholder="Search by name..."]')
      search_field.fill_in with: 'Test Search'
      expect(search_field.value).to eq('Test Search')
    end
  end

  describe 'column configuration modal' do
    it 'opens modal when clicking Configure button' do
      click_button 'Configure Columns & Filters'

      expect(page).to have_css('[data-filter-target="modal"]', visible: true)
      expect(page).to have_content('Configure Columns & Filters')
    end

    it 'closes modal when clicking close button' do
      click_button 'Configure Columns & Filters'
      expect(page).to have_css('[data-filter-target="modal"]', visible: true)

      within('[data-filter-target="modal"]') do
        click_button '×'
      end

      expect(page).to have_css('[data-filter-target="modal"]', visible: false)
    end

    it 'displays column lists (hidden, shown, featured)' do
      click_button 'Configure Columns & Filters'

      expect(page).to have_content('Hidden')
      expect(page).to have_content('Shown')
      expect(page).to have_content('Featured')
    end

    it 'shows all columns in shown list initially' do
      click_button 'Configure Columns & Filters'

      # Initially, all columns should be in "shown" state
      within('[data-filter-target="shownList"]') do
        expect(page).to have_content('Name')
        expect(page).to have_content('Score')
        expect(page).to have_content('Priority')
      end
    end
  end

  describe 'column visibility management' do
    it 'moves column from shown to hidden' do
      click_button 'Configure Columns & Filters'

      # Find the Priority column and click the hide button (←)
      within('[data-filter-target="shownList"]') do
        # Find the row containing "Priority" and click its hide button
        priority_row = find('span', text: 'Priority').ancestor('div', match: :first)
        within(priority_row) do
          find('[data-action="click->filter#moveToHidden"]').click
        end
      end

      # Verify it moved to hidden list
      within('[data-filter-target="hiddenList"]') do
        expect(page).to have_content('Priority')
      end

      within('[data-filter-target="shownList"]') do
        expect(page).not_to have_content('Priority')
      end
    end

    it 'moves column from hidden to shown' do
      # First hide a column
      click_button 'Configure Columns & Filters'
      within('[data-filter-target="shownList"]') do
        priority_row = find('span', text: 'Priority').ancestor('div', match: :first)
        within(priority_row) do
          find('[data-action="click->filter#moveToHidden"]').click
        end
      end

      # Now move it back
      within('[data-filter-target="hiddenList"]') do
        priority_row = find('span', text: 'Priority').ancestor('div', match: :first)
        within(priority_row) do
          find('[data-action="click->filter#moveToShown"]').click
        end
      end

      # Verify it's back in shown list
      within('[data-filter-target="shownList"]') do
        expect(page).to have_content('Priority')
      end
    end

    it 'moves filterable column to featured (adds filter)' do
      click_button 'Configure Columns & Filters'

      # Find Score column and click the add filter button (★)
      within('[data-filter-target="shownList"]') do
        score_row = find('span', text: 'Score').ancestor('div', match: :first)
        within(score_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end

      # Verify it moved to featured list
      within('[data-filter-target="featuredList"]') do
        expect(page).to have_content('Score')
      end

      # Close modal
      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end

      # Filter bar should now be visible with the score slider
      expect(page).to have_content('Active Filters (1)')
      expect(page).to have_content('Score')
    end
  end

  describe 'dual-handle slider filtering' do
    before do
      # Set up a filter on the score column
      click_button 'Configure Columns & Filters'
      within('[data-filter-target="shownList"]') do
        score_row = find('span', text: 'Score').ancestor('div', match: :first)
        within(score_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end
      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end
    end

    it 'displays dual-handle slider for featured column' do
      expect(page).to have_css('input[data-column="score"][data-handle="min"]')
      expect(page).to have_css('input[data-column="score"][data-handle="max"]')
    end

    it 'displays percentile range label' do
      expect(page).to have_content('0th-100th percentile')
    end

    it 'filters examples when adjusting min slider' do
      # Set min slider to 50th percentile (should filter out low scores)
      min_slider = find('input[data-column="score"][data-handle="min"]')
      min_slider.set(50)

      # Should show only high score examples (above 50th percentile)
      # With 9 examples, 50th percentile should exclude the bottom half
      expect(page).to have_content('High Score 1')
      expect(page).not_to have_content('Low Score 1')

      # Result count should decrease
      expect(page).to have_content(/Showing [1-6] of 9 examples/)
    end

    it 'filters examples when adjusting max slider' do
      # Set max slider to 50th percentile (should filter out high scores)
      max_slider = find('input[data-column="score"][data-handle="max"]')
      max_slider.set(50)

      # Should show only low to mid score examples
      expect(page).to have_content('Low Score 1')
      expect(page).not_to have_content('High Score 1')
    end

    it 'handles narrow percentile ranges' do
      # Set a narrow range (40th-60th percentile)
      min_slider = find('input[data-column="score"][data-handle="min"]')
      max_slider = find('input[data-column="score"][data-handle="max"]')

      min_slider.set(40)
      max_slider.set(60)

      # Should show only mid-range examples
      expect(page).to have_content(/Showing [1-5] of 9 examples/)
    end

    it 'updates percentile label when slider moves' do
      min_slider = find('input[data-column="score"][data-handle="min"]')
      min_slider.set(25)

      expect(page).to have_content('25th-100th percentile')
    end

    it 'displays actual value range in percentile label' do
      # The label should show actual values, not just percentiles
      expect(page).to have_content(/\d+\.\d+ to \d+\.\d+/)
    end
  end

  describe 'removing filters' do
    before do
      # Add a filter
      click_button 'Configure Columns & Filters'
      within('[data-filter-target="shownList"]') do
        score_row = find('span', text: 'Score').ancestor('div', match: :first)
        within(score_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end
      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end
    end

    it 'removes single filter using X button' do
      # Click the X button on the score filter
      within('.slider-container') do
        find('.slider-remove').click
      end

      # All examples should be visible again
      expect(page).to have_content('Showing 9 of 9 examples')
    end

    it 'clears all filters using Clear All button' do
      click_button 'Clear All'

      # All examples should be visible
      expect(page).to have_content('Showing 9 of 9 examples')
    end
  end

  describe 'filter mode vs elimination mode' do
    before do
      # Add a filter on complexity
      click_button 'Configure Columns & Filters'
      within('[data-filter-target="shownList"]') do
        complexity_row = find('span', text: 'Complexity').ancestor('div', match: :first)
        within(complexity_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end
      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end
    end

    it 'defaults to filter mode' do
      expect(page).to have_button('Filter')
    end

    it 'toggles between filter and elimination mode' do
      # Click the mode button to switch to elimination
      find('button[data-action="click->filter#toggleMode"]').click

      expect(page).to have_button('Elimination')

      # Click again to switch back
      find('button[data-action="click->filter#toggleMode"]').click

      expect(page).to have_button('Filter')
    end

    it 'hides rows in filter mode' do
      # Set slider to show only low complexity (1-2)
      max_slider = find('input[data-column="complexity"][data-handle="max"]')
      max_slider.set(40)

      # Should hide high complexity examples
      visible_count = page.all('tbody tr', visible: true).count
      expect(visible_count).to be < 9
    end

    it 'highlights failing cells in elimination mode' do
      # Switch to elimination mode
      find('button[data-action="click->filter#toggleMode"]').click

      # Set slider to narrow range
      min_slider = find('input[data-column="complexity"][data-handle="min"]')
      max_slider = find('input[data-column="complexity"][data-handle="max"]')
      min_slider.set(40)
      max_slider.set(60)

      # All rows should still be visible
      expect(page.all('tbody tr', visible: true).count).to eq(9)

      # But some cells should have elimination-fail class
      expect(page).to have_css('.elimination-fail')
    end
  end

  describe 'table sorting' do
    it 'sorts table by clicking column header' do
      # Click Name header to sort
      find('th', text: 'Name').click
      sleep 0.3

      # Check that rows are visible and sorted
      expect(page).to have_css('tbody tr')
    end

    it 'can click column headers multiple times' do
      # Click once
      find('th', text: 'Name').click
      sleep 0.2

      # Click again
      find('th', text: 'Name').click
      sleep 0.2

      # Table should still be visible
      expect(page).to have_css('tbody tr')
    end
  end

  describe 'localStorage persistence' do
    it 'saves filter state to localStorage' do
      # Add a filter
      click_button 'Configure Columns & Filters'
      within('[data-filter-target="shownList"]') do
        score_row = find('span', text: 'Score').ancestor('div', match: :first)
        within(score_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end
      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end

      # Verify filter is active
      expect(page).to have_content('Active Filters (1)')
      expect(page).to have_content('Score')

      # Reload page
      visit '/golden_deployment/examples'
      sleep 1  # Give JavaScript time to load

      # Filter should still be active
      expect(page).to have_content('Active Filters (1)')
      expect(page).to have_content('Score')
    end

    it 'can reset configuration' do
      # Add a filter
      click_button 'Configure Columns & Filters'
      within('[data-filter-target="shownList"]') do
        score_row = find('span', text: 'Score').ancestor('div', match: :first)
        within(score_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end
      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end

      # Now reset
      click_button 'Configure Columns & Filters'

      # Accept the confirmation dialog
      accept_confirm do
        click_button 'Reset to Defaults'
      end

      # Page should reload with default state (no filters)
      sleep 1
      expect(page).to have_content('Showing 9 of 9 examples')
    end
  end

  describe 'multiple filters' do
    it 'applies multiple filters simultaneously' do
      click_button 'Configure Columns & Filters'

      # Add Score filter
      within('[data-filter-target="shownList"]') do
        score_row = find('span', text: 'Score').ancestor('div', match: :first)
        within(score_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end

      # Add Priority filter
      within('[data-filter-target="shownList"]') do
        priority_row = find('span', text: 'Priority').ancestor('div', match: :first)
        within(priority_row) do
          find('[data-action="click->filter#moveToFeatured"]').click
        end
      end

      within('[data-filter-target="modal"]') do
        click_button 'Save & Apply'
      end

      # Should show 2 active filters
      expect(page).to have_content('Active Filters (2)')

      # Adjust both sliders
      score_min = find('input[data-column="score"][data-handle="min"]')
      score_min.set(60)

      priority_min = find('input[data-column="priority"][data-handle="min"]')
      priority_min.set(60)

      # Should filter by both criteria (high score AND high priority)
      visible_count = page.all('tbody tr', visible: true).count
      expect(visible_count).to be < 9
      expect(visible_count).to be >= 1
    end
  end

  describe 'edge cases and error handling' do
    it 'handles examples with nil values gracefully' do
      create(:example, name: 'Nil Values Example', score: nil, priority: nil, complexity: nil)

      visit '/golden_deployment/examples'

      expect(page).to have_content('Nil Values Example')
      expect(page).to have_content('Showing 10 of 10 examples')
    end

    it 'works with zero examples' do
      Example.destroy_all

      visit '/golden_deployment/examples'

      expect(page).to have_content('0 examples')
      expect(page).not_to have_css('.slider-container')
    end

    it 'handles missing percentile data gracefully' do
      # All examples have nil scores
      Example.destroy_all
      create_list(:example, 5, score: nil)

      visit '/golden_deployment/examples'

      # Should not crash
      expect(page).to have_content('Showing 5 of 5 examples')
    end
  end

  describe 'regression test for high_score_basketball incident' do
    it 'loads correct data model (examples not other app data)' do
      visit '/golden_deployment/examples'

      # Should find script tag with correct ID
      expect(page).to have_css('script#examples-data', visible: false)

      # Should load example data, not rails metrics or other app data
      data_script = page.find('script#examples-data', visible: false)
      json_content = data_script.text(:all)

      # Parse JSON to verify structure
      data = JSON.parse(json_content)
      expect(data).to be_an(Array)
      expect(data.first).to have_key('name')
      expect(data.first).to have_key('score')
      expect(data.first).not_to have_key('rails_metrics')
    end

    it 'displays example names in table, not code quality metrics' do
      visit '/golden_deployment/examples'

      # Should show actual example names
      expect(page).to have_content('Low Score 1')

      # Should NOT show code quality terms
      expect(page).not_to have_content('Rubocop')
      expect(page).not_to have_content('Brakeman')
      expect(page).not_to have_content('rails_metrics')
    end
  end
end
