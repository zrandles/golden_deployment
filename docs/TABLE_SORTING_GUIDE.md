# Table Sorting Guide

**Status**: Production-tested pattern used in golden_deployment and bull_attributes
**Complexity**: Simple (50 lines of code)
**When to use**: Any table that needs sortable columns

## The Problem We Solved

During high_score_basketball development, we spent **hours** debugging table sorting because we deviated from the proven pattern. This guide prevents that from happening again.

## ❌ What NOT to Do

**Don't:**
- Store row references in instance variables (`this.allRows`) - they become stale after DOM manipulation
- Use `innerHTML = ''` - it destroys DOM nodes you're trying to sort
- Overcomplicate with dataset attributes for sorting
- Try to be clever with Stimulus data-action bindings
- Cache DOM references that you manipulate

**Why these fail:**
- Once you manipulate the DOM (appendChild, innerHTML), your cached references point to detached or stale nodes
- Dataset attributes are unnecessary - the cell textContent is already there
- Complex state management leads to bugs

## ✅ The Proven Pattern (from golden_deployment)

### 1. Use a Global Function (Simple)

```javascript
/**
 * Global sortTable function for table header clicks
 * Sorts visible rows by column index
 */
window.sortTable = function(columnIndex) {
  const table = document.querySelector('[data-filter-target="table"]')
  const tbody = table.querySelector('tbody')
  const rows = Array.from(tbody.querySelectorAll('tr[style=""]'))  // Only visible rows

  // Get current sort direction from header
  const headers = table.querySelectorAll('th')
  const header = headers[columnIndex]
  const currentSort = header.dataset.sort || ''
  const newSort = currentSort === 'asc' ? 'desc' : 'asc'

  // Clear all header sorts and indicators
  headers.forEach(th => {
    th.dataset.sort = ''
    const text = th.textContent.replace(/ [▲▼]$/, '')
    th.textContent = text
  })

  // Set new sort and add indicator
  header.dataset.sort = newSort
  const headerText = header.textContent.replace(/ [▲▼]$/, '')
  header.textContent = headerText + (newSort === 'asc' ? ' ▲' : ' ▼')

  // Sort rows
  rows.sort((a, b) => {
    let aVal = a.cells[columnIndex].textContent.trim()
    let bVal = b.cells[columnIndex].textContent.trim()

    // Try numeric sort first
    const aNum = parseFloat(aVal)
    const bNum = parseFloat(bVal)

    if (!isNaN(aNum) && !isNaN(bNum)) {
      return newSort === 'asc' ? aNum - bNum : bNum - aNum
    }

    // Fall back to text sort
    return newSort === 'asc'
      ? aVal.localeCompare(bVal)
      : bVal.localeCompare(aVal)
  })

  // Reattach sorted rows (appendChild MOVES existing nodes)
  rows.forEach(row => tbody.appendChild(row))
}
```

### 2. HTML Pattern

```erb
<th class="sortable cursor-pointer" onclick="window.sortTable(0)">Player Name</th>
<th class="sortable cursor-pointer" onclick="window.sortTable(1)">Team</th>
<th class="sortable cursor-pointer" onclick="window.sortTable(2)">Points</th>
```

## Key Principles

### 1. Query Fresh Every Time
```javascript
// ✅ GOOD - Fresh query each time
const rows = Array.from(tbody.querySelectorAll('tr'))

// ❌ BAD - Stale reference after DOM manipulation
this.allRows = Array.from(tbody.querySelectorAll('tr'))
// ... later after sorting ...
this.allRows.forEach(row => tbody.appendChild(row)) // Points to old nodes!
```

### 2. Use appendChild to Move Nodes
```javascript
// ✅ GOOD - appendChild MOVES existing nodes to new position
rows.forEach(row => tbody.appendChild(row))

// ❌ BAD - Destroys nodes you're trying to sort
tbody.innerHTML = ''
rows.forEach(row => tbody.appendChild(row)) // Rows are now detached!
```

### 3. Read Cell Text Directly
```javascript
// ✅ GOOD - Read what's displayed
let aVal = a.cells[columnIndex].textContent.trim()

// ❌ BAD - Requires maintaining parallel data-* attributes
let aVal = a.dataset.someValue
```

### 4. Sort by Column Index, Not Name
```javascript
// ✅ GOOD - Simple column index
onclick="window.sortTable(3)"

// ❌ BAD - Requires mapping column names to indexes
data-column="last_7_days_high"
// Then: const columnIndex = this.columnMap[columnName]
```

## The Working Solution (50 lines)

1. **Query fresh rows from DOM** - don't cache
2. **Sort the array** using cell textContent
3. **Move nodes** with appendChild (don't destroy/recreate)
4. **Keep it simple** - global function, column index, onclick

## Testing

Always include system tests for sorting:

```ruby
RSpec.describe "Table sorting", type: :system, js: true do
  it "sorts by column on click" do
    visit root_path

    find('th', text: 'Points').click

    rows = page.all('tbody tr')
    expect(rows[0]).to have_content("95.7")
    expect(rows[-1]).to have_content("76.9")
  end
end
```

## Lessons from high_score_basketball

**What we did wrong:**
1. Tried to use Stimulus data-action instead of simple onclick
2. Cached rows in `this.allRows` instead of querying fresh
3. Used `innerHTML = ''` which destroyed nodes
4. Maintained separate dataset attributes instead of reading textContent
5. Mapped column names to indexes instead of using indexes directly

**Time wasted:** ~3 hours
**Number of "fixes" deployed that didn't work:** 8
**Number of lines of broken code:** ~150
**Working solution:** 50 lines

## Quick Reference

```javascript
// Copy this pattern for any new table:

window.sortTable = function(colIndex) {
  const tbody = document.querySelector('tbody')
  const rows = Array.from(tbody.querySelectorAll('tr'))

  rows.sort((a, b) => {
    const aVal = a.cells[colIndex].textContent.trim()
    const bVal = b.cells[colIndex].textContent.trim()
    const aNum = parseFloat(aVal)
    const bNum = parseFloat(bVal)

    if (!isNaN(aNum) && !isNaN(bNum)) {
      return bNum - aNum // descending
    }
    return bVal.localeCompare(aVal)
  })

  rows.forEach(row => tbody.appendChild(row))
}
```

```erb
<th onclick="window.sortTable(0)">Column 1</th>
<th onclick="window.sortTable(1)">Column 2</th>
```

**That's it. Don't overcomplicate it.**
