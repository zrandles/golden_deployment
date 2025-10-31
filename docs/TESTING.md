# Testing Strategy for Golden Deployment

## Overview

Golden Deployment uses a comprehensive, production-grade testing approach based on the **Testing Pyramid**:

```
        /\
       /  \      Few: System Tests (JavaScript/Browser)
      /    \
     /------\    Some: Request Tests (Controllers/Routes)
    /        \
   /----------\  Many: Model Tests (Business Logic)
  /__________
```

**Testing Philosophy**: Tests are safeguards that prevent production incidents. Every bug that reaches production represents a missing test case.

## Test Suite Components

### 1. Model Tests (`spec/models/`)

**Coverage**: Business logic, validations, associations, calculations

**Example** (`spec/models/example_spec.rb`):
- All validations (presence, inclusion, numericality)
- Constants (STATUSES, CATEGORIES)
- Calculated fields (`#average_metrics`)
- Status helpers (`#new?`, `#completed?`)
- Factory traits (high_performer, low_performer, etc.)

**Best Practices**:
- Use shoulda-matchers for clean validation testing
- Test edge cases (nil values, boundary conditions)
- Verify calculated fields with different input combinations
- Keep tests fast (no database hits unless necessary)

### 2. Request Tests (`spec/requests/`)

**Coverage**: Controller actions, routing, response codes, data assignment

**Example** (`spec/requests/examples_spec.rb`):
- GET requests return 200 OK
- Templates render correctly
- Instance variables assigned properly
- JSON data embedded in responses
- Percentile calculations accurate
- Performance benchmarks (200 records < 2 seconds)

**Best Practices**:
- Test happy path and error cases
- Verify data structure in responses
- Test with realistic data volumes
- Check performance under load
- No JavaScript testing here (use system tests)

### 3. System Tests (`spec/system/`) - MOST CRITICAL

**Coverage**: JavaScript controllers, user interactions, browser behavior

**Example** (`spec/system/filter_controller_spec.rb`):
- Page loads without JavaScript errors
- Stimulus controllers initialize correctly
- Data loads from script tags (not wrong data!)
- Modal opens/closes
- Column visibility management
- Dual-handle slider filtering
- Search functionality
- Percentile calculations
- Filter vs Elimination modes
- Table sorting
- localStorage persistence
- Multiple simultaneous filters

**Best Practices**:
- **ALWAYS check browser console for errors**
- Use semantic selectors (not brittle CSS classes)
- Leverage Capybara's automatic waiting (no sleep)
- Test actual user workflows end-to-end
- Verify data integrity (correct model, not wrong app data)
- Test edge cases (nil values, empty datasets)

## Running Tests

### Run All Tests
```bash
bundle exec rspec
```

### Run Specific Test Types
```bash
# Model tests only
bundle exec rspec spec/models

# Request tests only
bundle exec rspec spec/requests

# System tests only (slowest)
bundle exec rspec spec/system

# Single file
bundle exec rspec spec/models/example_spec.rb

# Single test
bundle exec rspec spec/models/example_spec.rb:42
```

### With Coverage Report
```bash
COVERAGE=true bundle exec rspec
open coverage/index.html
```

### Watch Mode (run tests on file changes)
```bash
bundle exec guard
```

## Code Coverage

**Current Status**: ✅ **92.94% line coverage** (303/326 lines)

**Target**: 80% minimum (currently exceeding goal!)

**SimpleCov Configuration** (`spec/rails_helper.rb`):
- Enforces minimum 80% overall coverage
- Enforces minimum 60% per-file coverage
- Excludes `/spec/`, `/config/`, `/vendor/`
- Generates HTML report in `coverage/`
- **Fails build if coverage drops below 80%**

**View Coverage**:
```bash
bundle exec rspec
open coverage/index.html
```

**Coverage by Component**:
- ✅ Models: 100% (Example model fully covered)
- ✅ Controllers: 95%+ (Examples, API::Examples, API::Metrics)
- ✅ Services: 100% (ExampleService fully covered)
- ✅ Jobs: 100% (ExampleJob and variants fully covered)
- ✅ Helpers: 100% (ApplicationHelper, ExamplesHelper fully covered)
- ✅ System Tests: Comprehensive JavaScript/Stimulus coverage

## Factory Bot

**Location**: `spec/factories/examples.rb`

**Usage**:
```ruby
# Build (no database save)
example = build(:example)

# Create (save to database)
example = create(:example)

# Create list
examples = create_list(:example, 10)

# Use traits
high_performer = create(:example, :high_performer)
low_performer = create(:example, :low_performer)
ui_pattern = create(:example, :ui_pattern)

# Override attributes
example = create(:example, name: 'Custom Name', score: 95)
```

**Traits**:
- `:new_status`, `:in_progress`, `:completed`, `:archived`
- `:ui_pattern`, `:backend_pattern`, `:data_pattern`, `:deployment_pattern`
- `:high_performer` (score 80+, quality 4-5)
- `:low_performer` (score 0-20, quality 1-2)
- `:with_all_metrics`, `:without_metrics`

## CI/CD Integration

### GitHub Actions

**File**: `.github/workflows/test.yml`

**Runs on**:
- Every push to `main`
- Every pull request

**Steps**:
1. Install Ruby 3.3.4
2. Install dependencies
3. Set up test database
4. Precompile assets
5. Run full test suite
6. Upload coverage to Codecov
7. Verify 80% minimum coverage

### Pre-Deployment Hook

**File**: `config/deploy.rb`

**Hook**: `before 'deploy:starting', 'deploy:run_tests'`

**Behavior**:
- Runs full test suite locally before deploying
- Deployment aborts if any test fails
- Prevents broken code from reaching production

**Override** (use with extreme caution):
```bash
# Skip tests (NOT RECOMMENDED)
cap production deploy SKIP_TESTS=true
```

## Testing Workflow

### For New Features

1. **Write failing test first** (TDD approach)
2. Implement feature
3. Run tests until passing
4. Check coverage: `open coverage/index.html`
5. Refactor if needed
6. Commit with tests

### For Bug Fixes

1. **Write test that reproduces bug**
2. Verify test fails
3. Fix bug
4. Verify test passes
5. Check no regressions
6. Commit fix + test

### Before Deploying

```bash
# Run full test suite
bundle exec rspec

# Check coverage
open coverage/index.html

# If all green, deploy
cap production deploy
```

## Critical Test Cases

### Regression: high_score_basketball Incident

**What Happened**: JavaScript loaded wrong data model (rails_metrics instead of players)

**Prevention**: System test verifies:
```ruby
it 'loads correct data model (examples not other app data)' do
  visit '/golden_deployment/examples'

  # Should find script tag with correct ID
  expect(page).to have_css('script#examples-data', visible: false)

  # Parse JSON to verify structure
  data_script = page.find('script#examples-data', visible: false)
  data = JSON.parse(data_script.text(:all))

  expect(data.first).to have_key('name')
  expect(data.first).not_to have_key('rails_metrics')
end
```

**Lesson**: ALWAYS test JavaScript data loading with actual data verification.

### JavaScript Changes

**CRITICAL RULE**: Never deploy JavaScript changes without:
1. Running system tests locally
2. Opening browser and checking console
3. Testing actual functionality manually
4. Verifying correct data loads

**Why**: Server logs don't show JavaScript errors. Page returns 200 OK even when JS fails.

## Troubleshooting

### System Tests Failing

**Chrome not found**:
```bash
# Install Chrome
brew install --cask google-chrome
```

**Database locked**:
```bash
# Use database cleaner (already configured)
# Or reset test database
bin/rails db:reset RAILS_ENV=test
```

**Timing issues**:
```ruby
# Use Capybara's waiting helpers
expect(page).to have_content('Expected Text')  # Waits automatically

# NOT this:
sleep(2)  # Brittle!
```

### Coverage Not Updating

```bash
# Clear coverage cache
rm -rf coverage/
bundle exec rspec
```

### Factory Errors

```bash
# Lint factories
bundle exec rake factory_bot:lint
```

## Best Practices Summary

✅ **DO**:
- Write tests for every new feature
- Test edge cases and error conditions
- Use semantic selectors in system tests
- Leverage FactoryBot traits
- Check browser console in system tests
- Run tests before committing
- Maintain 80%+ coverage
- Document complex test scenarios

❌ **DON'T**:
- Skip system tests (they catch critical bugs)
- Use `sleep()` in tests
- Test implementation details
- Commit failing tests
- Deploy without running tests
- Ignore coverage drops
- Write brittle tests (CSS class selectors)
- Leave console errors unfixed

## Future Improvements

**Potential additions**:
- Integration tests for API endpoints
- Performance regression testing
- Visual regression testing (Percy/BackstopJS)
- Mutation testing (Mutant gem)
- Property-based testing (rspec-parameterized)

## Resources

- [RSpec Documentation](https://rspec.info/)
- [Capybara Cheat Sheet](https://gist.github.com/zhengjia/428105)
- [FactoryBot Getting Started](https://github.com/thoughtbot/factory_bot/blob/main/GETTING_STARTED.md)
- [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers)
- [SimpleCov](https://github.com/simplecov-ruby/simplecov)

---

**Last Updated**: 2025-10-31
**Maintained By**: Principal Test Engineer Agent
**Coverage Status**: 92.94% (EXCEEDS 80% TARGET)
**Test Suite**: 169 examples, 0 failures
