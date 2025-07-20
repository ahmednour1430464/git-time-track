# Git Time Tracking Script

## Overview

The Enhanced Git Time Tracking Script is a sophisticated Bash utility designed to analyze Git commit history and estimate the time spent on development work within a specified date range. Unlike simple commit counting tools, this script employs intelligent algorithms to provide realistic time estimates based on commit patterns, code complexity, and development session analysis.

## Key Features

### 🎯 **Intelligent Time Estimation**
- **Adaptive Session Detection**: Automatically groups commits into work sessions with configurable gap thresholds (default: 4 hours)
- **Complexity-Based Weighting**: Analyzes file changes, lines added/removed, and applies intelligent multipliers for more accurate estimates
- **Contextual Time Assignment**: Distinguishes between first commits, session continuations, and new work sessions
- **Smart Bounds Enforcement**: Applies realistic minimum (15 minutes) and maximum (8 hours) time limits per commit

### 📊 **Comprehensive Analysis**
- **File Change Statistics**: Tracks files modified, lines added, and lines removed per commit
- **Complexity Scoring**: Calculates complexity multipliers based on:
  - Total lines changed (50+ lines = 1.2x, 100+ = 1.5x, 200+ = 2.0x multiplier)
  - Number of files modified (5+ files = 1.1x, 10+ = 1.3x multiplier)
- **Session Grouping**: Intelligently groups commits into logical work sessions
- **Statistical Summary**: Provides total time, average time per commit, and detailed breakdowns

### 🔧 **Flexible Configuration**
- **Multiple Output Formats**: Human-readable, JSON, and verbose modes
- **Configurable Parameters**: Customizable session gaps, time bounds, and multipliers via config files
- **Author Detection**: Auto-detects Git user email or accepts manual specification
- **Date Range Filtering**: Supports flexible date range queries with validation

### 🛡️ **Robust Error Handling**
- **Input Validation**: Validates date formats, Git repository presence, and author emails
- **Comprehensive Error Messages**: Clear, actionable error messages with usage examples
- **Safe Execution**: Uses `set -euo pipefail` for strict error handling
- **Graceful Fallbacks**: Handles missing data and edge cases elegantly

## How It Works

### Time Estimation Algorithm

The script uses a multi-layered approach to estimate development time:

1. **Commit Gap Analysis**: Measures time between consecutive commits
2. **Session Boundary Detection**: Identifies work session breaks (gaps > 4 hours)
3. **Complexity Assessment**: Analyzes code changes to adjust time estimates
4. **Bounds Application**: Ensures realistic time ranges (15 minutes to 8 hours per commit)

### Complexity Factors

The algorithm considers several factors when estimating time:

- **Code Volume**: More lines changed = more time required
- **File Spread**: Changes across multiple files = coordination overhead
- **Change Type**: Additions vs. deletions vs. modifications
- **Session Context**: First commit vs. continuation work

## Usage Examples

### Basic Usage
```bash
# Analyze commits for current user in date range
./git-time-track "2025-07-01" "2025-07-20"

# Specify custom author
./git-time-track "2025-07-01" "2025-07-20" user@example.com
```

### Advanced Options
```bash
# Verbose output with detailed statistics
./git-time-track "2025-07-01" "2025-07-20" --verbose

# JSON output for integration with other tools
./git-time-track "2025-07-01" "2025-07-20" --json

# Use custom configuration file
./git-time-track "2025-07-01" "2025-07-20" --config custom-config.sh
```

## Configuration Options

### Default Settings
- **Maximum Session Gap**: 4 hours (commits separated by more are treated as new sessions)
- **Minimum Commit Time**: 15 minutes (prevents unrealistically low estimates)
- **Default Commit Time**: 30 minutes (used for first commits and new sessions)
- **Maximum Commit Time**: 8 hours (prevents unrealistically high estimates)

### Custom Configuration
Create a configuration file to override defaults:

```bash
# custom-config.sh
MAX_SESSION_GAP=$((2 * 60 * 60))     # 2 hours
MIN_COMMIT_TIME=$((10 * 60))         # 10 minutes
DEFAULT_COMMIT_TIME=$((20 * 60))     # 20 minutes
MAX_COMMIT_TIME=$((6 * 60 * 60))     # 6 hours
```

## Output Formats

### Standard Output
```
🔍 Analyzing commits for user@example.com between 2025-07-01 and 2025-07-20:

[2025-07-15 09:30:15] a1b2c3d4
  Message: Implement user authentication system
  Estimated Time: 02h 15m

[2025-07-15 11:45:22] e5f6g7h8
  Message: Add password validation
  Estimated Time: 45m
```

### Verbose Output
Includes additional details:
- Files changed count
- Lines added/removed
- Complexity multiplier applied

### JSON Output
Structured data for integration:
```json
{
  "author": "user@example.com",
  "total_commits": 15,
  "total_time_seconds": 28800,
  "total_time_formatted": "8h 0m",
  "commits": [...]
}
```

## Use Cases

### Project Management
- **Time Tracking**: Accurate development time estimates for billing and planning
- **Sprint Analysis**: Understand actual vs. estimated development effort
- **Resource Planning**: Historical data for future project estimation

### Team Analytics
- **Developer Productivity**: Compare development patterns across team members
- **Code Complexity Trends**: Identify areas requiring more development time
- **Session Pattern Analysis**: Understand optimal development session lengths

### Personal Development
- **Work Pattern Analysis**: Understand your most productive coding sessions
- **Time Management**: Better estimate how long features actually take
- **Progress Tracking**: Visualize development effort over time

## Technical Requirements

- **Bash 4.0+**: Required for associative arrays and modern syntax
- **Git**: Must be executed within a Git repository
- **Standard Unix Tools**: `date`, `bc`, basic text processing utilities
- **Optional**: Custom configuration file support

## Limitations and Considerations

### Accuracy Factors
- **Assumes Linear Development**: Cannot account for thinking time, research, or debugging
- **Commit Granularity**: More frequent commits provide better time estimates
- **Context Switching**: Cannot detect work interruptions within commit gaps
- **Pair Programming**: May underestimate time for collaborative development

### Best Practices
- **Regular Commits**: Commit frequently for more accurate estimates
- **Descriptive Messages**: Better commit messages improve analysis quality
- **Consistent Authorship**: Ensure consistent email configuration across environments
- **Session Awareness**: Understand that estimates reflect coding time, not total project time

This script serves as a powerful tool for development time analysis, providing insights that can improve project planning, resource allocation, and personal productivity understanding.
