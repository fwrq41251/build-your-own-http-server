#!/usr/bin/env bash
#
# Local CodeCrafters test runner for "Build your own HTTP server" (Zig).
#
#   ./test.sh              # run the next unpassed stage
#   ./test.sh at4          # run one specific stage
#   ./test.sh at4 ia4      # run several stages in order
#   ./test.sh list         # list all stages and progress
#   ./test.sh show at4     # print a stage's instructions
#
# Progress is tracked in .cc-passed (one stage slug per line).
# Requires: bash, curl, awk, sed, tar. Works on Linux and macOS.
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COURSE_DIR=${CODECRAFTERS_COURSE_DIR:-"${XDG_CACHE_HOME:-$HOME/.cache}/codecrafters/courses/build-your-own-http-server"}
COURSE_SLUG=http-server
TESTER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/codecrafters/testers/$COURSE_SLUG"
PASSED_FILE="$PROJECT_DIR/.cc-passed"
STAGES_FILE="$PROJECT_DIR/stages.tsv"

if [[ ! -f "$STAGES_FILE" ]]; then
  echo "Missing $STAGES_FILE" >&2
  exit 1
fi

stage_name() {
  awk -F '\t' -v slug="$1" '$1 == slug { print $2; found = 1 } END { exit !found }' "$STAGES_FILE"
}

stage_exists() {
  awk -F '\t' -v slug="$1" '$1 == slug { found = 1 } END { exit !found }' "$STAGES_FILE"
}

show_stage() {
  local slug=$1 file
  for file in "$COURSE_DIR"/stage_descriptions/*-"$slug".md; do
    if [[ -e "$file" ]]; then
      cat "$file"
      return
    fi
  done
  echo "No description found for stage: $slug" >&2
  echo "Course cache: $COURSE_DIR" >&2
  exit 1
}

next_stage() {
  local slug
  while IFS=$'\t' read -r slug _ _; do
    if ! grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null; then
      echo "$slug"
      return
    fi
  done < "$STAGES_FILE"
}

mark_passed() {
  local slug=$1
  grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null || echo "$slug" >> "$PASSED_FILE"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cmd=${1:-next}
case "$cmd" in
  list)
    echo "Stage  Slug  Name"
    echo "-----  ----  ----"
    while IFS=$'\t' read -r slug name extension; do
      mark=" "
      grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null && mark="x"
      printf '[%s] %-4s %-38s (%s)\n' "$mark" "$slug" "$name" "$extension"
    done < "$STAGES_FILE"
    exit 0
    ;;
  show)
    [[ $# -eq 2 ]] || { echo "Usage: $0 show <stage-slug>" >&2; exit 1; }
    show_stage "$2"
    exit 0
    ;;
  next)
    stage=$(next_stage)
    if [[ -z "$stage" ]]; then
      echo "All stages passed. Nice work!"
      exit 0
    fi
    stages=("$stage")
    ;;
  *)
    stages=("$@")
    ;;
esac

for stage in "${stages[@]}"; do
  stage_exists "$stage" || { echo "Unknown stage slug: $stage (try ./test.sh list)" >&2; exit 1; }
done

# Download the latest tester once, then reuse it from the cache.
version=$(curl -fsSL "https://api.github.com/repos/codecrafters-io/${COURSE_SLUG}-tester/releases/latest" \
  | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
if [[ -z "$version" ]]; then
  echo "Could not determine the latest tester version (network/rate limit?)" >&2
  exit 1
fi

tester_dir="$TESTER_CACHE/$version"
if [[ ! -x "$tester_dir/tester" ]]; then
  mkdir -p "$tester_dir"
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  [[ "$arch" == "x86_64" ]] && arch=amd64
  [[ "$arch" == "aarch64" ]] && arch=arm64
  url="https://github.com/codecrafters-io/${COURSE_SLUG}-tester/releases/download/$version/${version}_${os}_${arch}.tar.gz"
  echo "Downloading tester $version for $os/$arch..."
  curl -fsSL "$url" | tar xz -C "$tester_dir"
fi

# Build the CODECRAFTERS_TEST_CASES_JSON payload from stages.tsv.
test_cases_json="["
index=0
for stage in "${stages[@]}"; do
  name=$(stage_name "$stage")
  index=$((index + 1))
  [[ $index -gt 1 ]] && test_cases_json+=","
  test_cases_json+=$(printf '{"slug":"%s","tester_log_prefix":"stage-%d","title":"Stage #%d: %s"}' \
    "$stage" "$index" "$index" "$(json_escape "$name")")
done
test_cases_json+="]"

skip_anti_cheat=true
[[ ${CC_RUN_ANTI_CHEAT:-0} == "1" ]] && skip_anti_cheat=false

cd "$PROJECT_DIR"
CODECRAFTERS_REPOSITORY_DIR="$PROJECT_DIR" \
CODECRAFTERS_TEST_CASES_JSON="$test_cases_json" \
CODECRAFTERS_SKIP_ANTI_CHEAT="$skip_anti_cheat" \
"$tester_dir/tester"

for stage in "${stages[@]}"; do
  mark_passed "$stage"
done
