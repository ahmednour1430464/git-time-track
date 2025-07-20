#!/bin/bash

# Git Time Tracking Script
# Usage: ./git-time-track "2025-07-01" "2025-07-20" [your_email@example.com]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly MAX_SESSION_GAP=$((4 * 60 * 60))     # 4 hours max gap between commits in same session
readonly MIN_COMMIT_TIME=$((15 * 60))         # Minimum 15 minutes per commit
readonly DEFAULT_COMMIT_TIME=$((30 * 60))     # Default 30 minutes if can't infer
readonly MAX_COMMIT_TIME=$((8 * 60 * 60))     # Maximum 8 hours per commit

# Initialize variables
START_DATE=""
END_DATE=""
AUTHOR=""
VERBOSE=false
JSON_OUTPUT=false
CONFIG_FILE=""

show_help() {
    cat << EOF
Usage: $0 <start-date> <end-date> [author-email] [options]

Arguments:
    start-date      Start date in YYYY-MM-DD format
    end-date        End date in YYYY-MM-DD format  
    author-email    Git author email (optional, uses git config if not provided)

Options:
    --help, -h      Show this help message
    --verbose, -v   Show detailed analysis including file changes
    --json          Output results in JSON format
    --config FILE   Use custom configuration file

Examples:
    $0 "2025-07-01" "2025-07-20"
    $0 "2025-07-01" "2025-07-20" user@example.com --verbose
    $0 "2025-07-01" "2025-07-20" --verbose
    $0 "2025-07-01" "2025-07-20" --json
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
        *)
            # Parse positional arguments
            if [[ -z "$START_DATE" ]]; then
                START_DATE="$1"
            elif [[ -z "$END_DATE" ]]; then
                END_DATE="$1"
            elif [[ -z "$AUTHOR" ]]; then
                AUTHOR="$1"
            else
                echo "Too many arguments: $1" >&2
                show_help >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Load custom configuration if provided
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Validation
if [[ -z "$START_DATE" || -z "$END_DATE" ]]; then
    echo "Error: Start date and end date are required." >&2
    show_help >&2
    exit 1
fi

# Validate date format
if ! date -d "$START_DATE" >/dev/null 2>&1 || ! date -d "$END_DATE" >/dev/null 2>&1; then
    echo "Error: Invalid date format. Use YYYY-MM-DD." >&2
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository." >&2
    exit 1
fi

# Auto-detect Git author email if not provided
if [[ -z "$AUTHOR" ]]; then
    AUTHOR=$(git config user.email 2>/dev/null || echo "")
    if [[ -z "$AUTHOR" ]]; then
        echo "Error: Author email not provided and not found in git config." >&2
        echo "Please provide email as third argument or set git config user.email" >&2
        exit 1
    fi
fi

log_info() {
    if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo "$@"
    fi
}

# Enhanced commit analysis with file changes and complexity estimation
analyze_commit_complexity() {
    local hash="$1"
    local files_changed lines_added lines_removed
    
    # Get file change statistics
    local stats
    stats=$(git show --stat --format="" "$hash" | tail -n 1)
    
    if [[ "$stats" =~ ([0-9]+)\ file[s]?\ changed ]]; then
        files_changed="${BASH_REMATCH[1]}"
    else
        files_changed=1
    fi
    
    if [[ "$stats" =~ ([0-9]+)\ insertion[s]? ]]; then
        lines_added="${BASH_REMATCH[1]}"
    else
        lines_added=0
    fi
    
    if [[ "$stats" =~ ([0-9]+)\ deletion[s]? ]]; then
        lines_removed="${BASH_REMATCH[1]}"
    else
        lines_removed=0
    fi
    
    # Calculate complexity multiplier based on changes
    local total_lines=$((lines_added + lines_removed))
    local complexity_multiplier=1.0
    
    if [[ $total_lines -gt 200 ]]; then
        complexity_multiplier=2.0
    elif [[ $total_lines -gt 100 ]]; then
        complexity_multiplier=1.5
    elif [[ $total_lines -gt 50 ]]; then
        complexity_multiplier=1.2
    fi
    
    if [[ $files_changed -gt 10 ]]; then
        complexity_multiplier=$(echo "$complexity_multiplier * 1.3" | bc -l)
    elif [[ $files_changed -gt 5 ]]; then
        complexity_multiplier=$(echo "$complexity_multiplier * 1.1" | bc -l)
    fi
    
    echo "$files_changed|$lines_added|$lines_removed|$complexity_multiplier"
}

# Improved time estimation algorithm
calculate_commit_time() {
    local gap="$1"
    local complexity_multiplier="$2"
    local is_first_commit="$3"
    
    local base_time
    
    if [[ "$is_first_commit" == "true" || "$gap" -gt "$MAX_SESSION_GAP" ]]; then
        # First commit or new session - use default time
        base_time=$DEFAULT_COMMIT_TIME
    else
        # Use the gap between commits as base time
        base_time=$gap
    fi
    
    # Apply complexity multiplier
    local estimated_time
    estimated_time=$(echo "$base_time * $complexity_multiplier" | bc -l | cut -d. -f1)
    
    # Enforce bounds
    if [[ $estimated_time -lt $MIN_COMMIT_TIME ]]; then
        estimated_time=$MIN_COMMIT_TIME
    elif [[ $estimated_time -gt $MAX_COMMIT_TIME ]]; then
        estimated_time=$MAX_COMMIT_TIME
    fi
    
    echo "$estimated_time"
}

# Get commits with enhanced information
COMMITS=$(git log --since="$START_DATE" --until="$END_DATE" --author="$AUTHOR" \
    --pretty=format:"%H|%ct|%s" --reverse)

if [[ -z "$COMMITS" ]]; then
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo '{"commits": [], "total_time_seconds": 0, "total_commits": 0, "author": "'$AUTHOR'"}'
    else
        echo "No commits found for $AUTHOR between $START_DATE and $END_DATE"
    fi
    exit 0
fi

# Initialize variables
PREV_TIMESTAMP=0
TOTAL_SECONDS=0
COMMIT_COUNT=0
declare -a COMMIT_DATA

log_info "🔍 Analyzing commits for $AUTHOR between $START_DATE and $END_DATE:"
log_info ""

# Process commits
while IFS='|' read -r HASH TIMESTAMP MESSAGE; do
    COMMIT_COUNT=$((COMMIT_COUNT + 1))
    
    # Analyze commit complexity
    COMPLEXITY_DATA=$(analyze_commit_complexity "$HASH")
    IFS='|' read -r FILES_CHANGED LINES_ADDED LINES_REMOVED COMPLEXITY_MULTIPLIER <<< "$COMPLEXITY_DATA"
    
    # Calculate time for this commit
    if [[ "$PREV_TIMESTAMP" -eq 0 ]]; then
        DURATION=$(calculate_commit_time 0 "$COMPLEXITY_MULTIPLIER" "true")
    else
        GAP=$((TIMESTAMP - PREV_TIMESTAMP))
        DURATION=$(calculate_commit_time "$GAP" "$COMPLEXITY_MULTIPLIER" "false")
    fi
    
    TOTAL_SECONDS=$((TOTAL_SECONDS + DURATION))
    
    # Format time display
    H=$((DURATION / 3600))
    M=$(((DURATION % 3600) / 60))
    TIME_STR=$(printf "%02dh %02dm" $H $M)
    
    COMMIT_TIME=$(date -d "@$TIMESTAMP" '+%Y-%m-%d %H:%M:%S')
    SHORT_HASH=${HASH:0:8}
    
    # Store commit data for JSON output
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        COMMIT_DATA+=("{\"hash\":\"$HASH\",\"short_hash\":\"$SHORT_HASH\",\"timestamp\":$TIMESTAMP,\"datetime\":\"$COMMIT_TIME\",\"message\":\"${MESSAGE//\"/\\\"}\",\"estimated_seconds\":$DURATION,\"files_changed\":$FILES_CHANGED,\"lines_added\":$LINES_ADDED,\"lines_removed\":$LINES_REMOVED}")
    else
        echo "[$COMMIT_TIME] $SHORT_HASH"
        echo "  Message: $MESSAGE"
        echo "  Estimated Time: $TIME_STR"
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  Files Changed: $FILES_CHANGED"
            echo "  Lines Added: $LINES_ADDED"
            echo "  Lines Removed: $LINES_REMOVED"
            echo "  Complexity Factor: $(printf "%.1f" "$COMPLEXITY_MULTIPLIER")"
        fi
        
        echo ""
    fi
    
    PREV_TIMESTAMP=$TIMESTAMP
done <<< "$COMMITS"

# Calculate summary statistics
TOTAL_HOURS=$((TOTAL_SECONDS / 3600))
TOTAL_MINUTES=$(((TOTAL_SECONDS % 3600) / 60))
AVG_TIME_PER_COMMIT=$((TOTAL_SECONDS / COMMIT_COUNT))
AVG_HOURS=$((AVG_TIME_PER_COMMIT / 3600))
AVG_MINUTES=$(((AVG_TIME_PER_COMMIT % 3600) / 60))

# Output results
if [[ "$JSON_OUTPUT" == "true" ]]; then
    # Join commit data array
    COMMITS_JSON=$(IFS=,; echo "${COMMIT_DATA[*]}")
    
    cat << EOF
{
  "author": "$AUTHOR",
  "start_date": "$START_DATE",
  "end_date": "$END_DATE",
  "total_commits": $COMMIT_COUNT,
  "total_time_seconds": $TOTAL_SECONDS,
  "total_time_formatted": "${TOTAL_HOURS}h ${TOTAL_MINUTES}m",
  "average_time_per_commit_seconds": $AVG_TIME_PER_COMMIT,
  "average_time_per_commit_formatted": "${AVG_HOURS}h ${AVG_MINUTES}m",
  "commits": [$COMMITS_JSON]
}
EOF
else
    echo "-------------------------------------"
    echo "📝 Summary:"
    echo "Author: $AUTHOR"
    echo "Period: $START_DATE to $END_DATE"
    echo "Total commits: $COMMIT_COUNT"
    echo "Total estimated time: ${TOTAL_HOURS}h ${TOTAL_MINUTES}m"
    echo "Average time per commit: ${AVG_HOURS}h ${AVG_MINUTES}m"
    echo "-------------------------------------"
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo "📊 Time Estimation Method:"
        echo "• Commits in same session (gap < 4h): Use actual time between commits"
        echo "• First commit or new session: Use default 30 minutes"
        echo "• Complexity multiplier based on files changed and lines modified"
        echo "• Minimum time per commit: 15 minutes"
        echo "• Maximum time per commit: 8 hours"
    fi
fi
