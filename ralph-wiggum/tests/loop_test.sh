#!/bin/bash

# Tests for loop.sh functions
# Run: ./loop_test.sh

# Note: Not using set -e because we need to test functions that return non-zero

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    echo -e "${GREEN}PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}: $message"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_true() {
  local result="$1"
  local message="$2"
  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$result" == "0" ]]; then
    echo -e "${GREEN}PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}: $message (expected true, got false)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_false() {
  local result="$1"
  local message="$2"
  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$result" != "0" ]]; then
    echo -e "${GREEN}PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}: $message (expected false, got true)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ============================================================================
# Functions under test (copied from loop.sh template)
# ============================================================================

is_usage_limit_error() {
  local output="$1"
  local exit_code="$2"

  # Check for Claude Max/Pro subscription limits
  # Format: "You've hit your limit · resets 6am (Asia/Jerusalem)"
  if [[ "$output" =~ "You've hit your limit" ]]; then
    return 0
  fi

  # Check for API rate_limit_error (structured JSON from API)
  if [[ "$output" =~ \"type\":\"rate_limit_error\" ]]; then
    return 0
  fi

  # Check for API overloaded_error (529 status)
  if [[ "$output" =~ \"type\":\"overloaded_error\" ]]; then
    return 0
  fi

  # Check for HTTP 429/529 status codes in error output
  if [[ "$output" =~ Error:\ 429 ]] || [[ "$output" =~ Error:\ 529 ]]; then
    return 0
  fi

  return 1
}

get_sleep_duration() {
  local output="$1"

  # First, try to extract reset time from JSON payload
  local json_reset=$(echo "$output" | grep -oE '"resetsAt"\s*:\s*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  if [[ -n "$json_reset" ]]; then
    local reset_epoch=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$json_reset" +%s 2>/dev/null || \
                        date -d "$json_reset" +%s 2>/dev/null)
    if [[ -n "$reset_epoch" ]]; then
      local now=$(date +%s)
      local diff=$((reset_epoch - now))
      if [[ $diff -gt 0 ]]; then
        echo $((diff + 60))
        return
      fi
    fi
  fi

  # Also check for reset_at in JSON (snake_case variant)
  local json_reset_alt=$(echo "$output" | grep -oE '"reset_at"\s*:\s*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  if [[ -n "$json_reset_alt" ]]; then
    local reset_epoch=$(date -jf "%Y-%m-%dT%H:%M:%S%z" "$json_reset_alt" +%s 2>/dev/null || \
                        date -d "$json_reset_alt" +%s 2>/dev/null)
    if [[ -n "$reset_epoch" ]]; then
      local now=$(date +%s)
      local diff=$((reset_epoch - now))
      if [[ $diff -gt 0 ]]; then
        echo $((diff + 60))
        return
      fi
    fi
  fi

  # Check for format: "resets 6am (Asia/Jerusalem)" or "resets 3pm (Europe/London)"
  if [[ "$output" =~ resets[[:space:]]+([0-9]+)(am|pm)[[:space:]]*\(([A-Za-z_/]+)\) ]]; then
    local hour="${BASH_REMATCH[1]}"
    local ampm="${BASH_REMATCH[2]}"
    local timezone="${BASH_REMATCH[3]}"

    if [[ "$ampm" == "pm" && "$hour" != "12" ]]; then
      hour=$((hour + 12))
    elif [[ "$ampm" == "am" && "$hour" == "12" ]]; then
      hour=0
    fi

    local now=$(date +%s)
    local today_date=$(TZ="$timezone" date +%Y-%m-%d)
    local reset_time=$(TZ="$timezone" date -jf "%Y-%m-%d %H:%M:%S" "$today_date $(printf '%02d' $hour):00:00" +%s 2>/dev/null || \
                       TZ="$timezone" date -d "$today_date $(printf '%02d' $hour):00:00" +%s 2>/dev/null)

    if [[ -n "$reset_time" ]]; then
      local diff=$((reset_time - now))
      if [[ $diff -lt 0 ]]; then
        diff=$((diff + 86400))
      fi
      echo $((diff + 60))
      return
    fi
  fi

  # Pattern: "try again in X minutes/hours"
  if [[ "$output" =~ "try again in "([0-9]+)" minute" ]]; then
    echo $(( ${BASH_REMATCH[1]} * 60 + 60 ))
    return
  fi

  if [[ "$output" =~ "try again in "([0-9]+)" hour" ]]; then
    echo $(( ${BASH_REMATCH[1]} * 3600 + 60 ))
    return
  fi

  # Default: return a fixed value for testing
  echo "3660"  # 1 hour + 1 minute
}

# ============================================================================
# Tests
# ============================================================================

echo "========================================"
echo "Running loop.sh function tests"
echo "========================================"
echo ""

# --- is_usage_limit_error tests ---

echo "--- is_usage_limit_error tests ---"
echo ""

# Test: New format with timezone
if is_usage_limit_error "You've hit your limit · resets 6am (Asia/Jerusalem)" ""; then
  assert_true "0" "Detects 'You've hit your limit' message"
else
  assert_true "1" "Detects 'You've hit your limit' message"
fi

# Test: Curly apostrophe variant
if is_usage_limit_error "You've hit your limit · resets 3pm (Europe/London)" ""; then
  assert_true "0" "Detects message with curly apostrophe"
else
  assert_true "1" "Detects message with curly apostrophe"
fi

# Test: API rate_limit_error JSON
if is_usage_limit_error '{"type":"error","error":{"type":"rate_limit_error","message":"Rate limit exceeded"}}' ""; then
  assert_true "0" "Detects API rate_limit_error JSON"
else
  assert_true "1" "Detects API rate_limit_error JSON"
fi

# Test: API overloaded_error JSON
if is_usage_limit_error '{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}' ""; then
  assert_true "0" "Detects API overloaded_error JSON"
else
  assert_true "1" "Detects API overloaded_error JSON"
fi

# Test: HTTP 429 error
if is_usage_limit_error "Error: 429 Too Many Requests" ""; then
  assert_true "0" "Detects HTTP 429 error"
else
  assert_true "1" "Detects HTTP 429 error"
fi

# Test: HTTP 529 error
if is_usage_limit_error "Error: 529 Overloaded" ""; then
  assert_true "0" "Detects HTTP 529 error"
else
  assert_true "1" "Detects HTTP 529 error"
fi

# Test: Normal output (should NOT match)
if is_usage_limit_error "Task completed successfully" ""; then
  assert_false "0" "Does not match normal output"
else
  assert_false "1" "Does not match normal output"
fi

# Test: Empty output (should NOT match)
if is_usage_limit_error "" ""; then
  assert_false "0" "Does not match empty output"
else
  assert_false "1" "Does not match empty output"
fi

# Test: Similar but different message (should NOT match)
if is_usage_limit_error "You have reached a milestone" ""; then
  assert_false "0" "Does not match unrelated 'reached' message"
else
  assert_false "1" "Does not match unrelated 'reached' message"
fi

echo ""

# --- get_sleep_duration tests ---

echo "--- get_sleep_duration tests ---"
echo ""

# Test: "try again in X minutes"
result=$(get_sleep_duration "Rate limited. Please try again in 5 minutes.")
assert_eq "360" "$result" "Parses 'try again in 5 minutes' (5*60+60=360)"

# Test: "try again in X hours"
result=$(get_sleep_duration "Rate limited. Please try again in 2 hours.")
assert_eq "7260" "$result" "Parses 'try again in 2 hours' (2*3600+60=7260)"

# Test: "resets Xam (Timezone)" format - verify it returns a positive number
result=$(get_sleep_duration "You've hit your limit · resets 6am (Asia/Jerusalem)")
if [[ "$result" =~ ^[0-9]+$ ]] && [[ "$result" -gt 0 ]]; then
  echo -e "${GREEN}PASS${NC}: Parses 'resets 6am (Asia/Jerusalem)' - returns $result seconds"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}FAIL${NC}: Parses 'resets 6am (Asia/Jerusalem)' - got '$result'"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test: "resets Xpm (Timezone)" format
result=$(get_sleep_duration "You've hit your limit · resets 3pm (Europe/London)")
if [[ "$result" =~ ^[0-9]+$ ]] && [[ "$result" -gt 0 ]]; then
  echo -e "${GREEN}PASS${NC}: Parses 'resets 3pm (Europe/London)' - returns $result seconds"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}FAIL${NC}: Parses 'resets 3pm (Europe/London)' - got '$result'"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test: Default fallback
result=$(get_sleep_duration "Some unknown error message")
if [[ "$result" =~ ^[0-9]+$ ]] && [[ "$result" -gt 0 ]]; then
  echo -e "${GREEN}PASS${NC}: Returns default duration for unknown message - $result seconds"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}FAIL${NC}: Default fallback failed - got '$result'"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test: JSON resetsAt field (future time)
future_time=$(date -v+1H "+%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || date -d "+1 hour" "+%Y-%m-%dT%H:%M:%S%z")
if [[ -n "$future_time" ]]; then
  result=$(get_sleep_duration "{\"error\":{\"resetsAt\":\"$future_time\"}}")
  if [[ "$result" =~ ^[0-9]+$ ]] && [[ "$result" -gt 0 ]] && [[ "$result" -lt 7300 ]]; then
    echo -e "${GREEN}PASS${NC}: Parses JSON resetsAt field - returns $result seconds"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}: JSON resetsAt parsing - got '$result' (expected ~3660)"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
fi

echo ""

# --- Argument parsing tests ---

echo "--- Argument parsing tests ---"
echo ""

# Test argument parsing by simulating it
test_arg_parsing() {
  local args="$1"
  local expected_mode="$2"
  local expected_auto="$3"
  local expected_max="$4"

  # Reset defaults (auto mode is default)
  MODE="plan"
  AUTO_MODE=true
  MAX_ITERATIONS=0

  for arg in $args; do
    if [[ "$arg" == "plan" ]]; then
      MODE="plan"
      AUTO_MODE=false
    elif [[ "$arg" == "build" ]]; then
      MODE="build"
      AUTO_MODE=false
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
      MAX_ITERATIONS=$arg
    fi
  done

  if [[ "$MODE" == "$expected_mode" && "$AUTO_MODE" == "$expected_auto" && "$MAX_ITERATIONS" == "$expected_max" ]]; then
    echo -e "${GREEN}PASS${NC}: Args '$args' -> mode=$MODE, auto=$AUTO_MODE, max=$MAX_ITERATIONS"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}FAIL${NC}: Args '$args'"
    echo "  Expected: mode=$expected_mode, auto=$expected_auto, max=$expected_max"
    echo "  Actual:   mode=$MODE, auto=$AUTO_MODE, max=$MAX_ITERATIONS"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Default (no args) should be auto mode
test_arg_parsing "" "plan" "true" "0"

# Explicit plan mode
test_arg_parsing "plan" "plan" "false" "0"

# Explicit build mode
test_arg_parsing "build" "build" "false" "0"

# Auto mode with max iterations
test_arg_parsing "10" "plan" "true" "10"

# Build mode with max iterations
test_arg_parsing "build 5" "build" "false" "5"

# Plan mode with max iterations
test_arg_parsing "plan 3" "plan" "false" "3"

echo ""

# ============================================================================
# Summary
# ============================================================================

echo "========================================"
echo "Test Results"
echo "========================================"
echo "Total:  $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
  exit 1
fi
