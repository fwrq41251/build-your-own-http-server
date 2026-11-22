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
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COURSE_DIR=${CODECRAFTERS_COURSE_DIR:-"$HOME/.cache/codecrafters/courses/build-your-own-http-server"}
COURSE_SLUG=http-server
TESTER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/codecrafters/testers/$COURSE_SLUG"
PASSED_FILE="$PROJECT_DIR/.cc-passed"

if [[ ! -f "$COURSE_DIR/course-definition.yml" ]]; then
  echo "Course definition not found at: $COURSE_DIR" >&2
  echo "Run: git clone --depth 1 https://github.com/codecrafters-io/build-your-own-http-server.git \"$COURSE_DIR\"" >&2
  exit 1
fi

# Prints "slug<TAB>name<TAB>extension" for every stage, in course order.
list_stages() {
  python3 - "$COURSE_DIR" <<'PY'
import sys, yaml

with open(f"{sys.argv[1]}/course-definition.yml") as f:
    course = yaml.safe_load(f)

for stage in course["stages"]:
    print(f"{stage['slug']}\t{stage['name']}\t{stage.get('primary_extension_slug') or 'base'}")
PY
}

show_stage() {
  local slug=$1
  local file
  file=$(find "$COURSE_DIR/stage_descriptions" -maxdepth 1 -name "*-$slug.md" -print -quit)
  if [[ -z "$file" ]]; then
    echo "No description found for stage: $slug" >&2
    exit 1
  fi
  cat "$file"
}

next_stage() {
  local slug
  while IFS=$'\t' read -r slug _ _; do
    if ! grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null; then
      echo "$slug"
      return
    fi
  done < <(list_stages)
}

mark_passed() {
  local slug=$1
  grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null || echo "$slug" >> "$PASSED_FILE"
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
    done < <(list_stages)
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

# Download the latest tester once, then reuse it from the cache.
version=$(curl -fsSL "https://api.github.com/repos/codecrafters-io/${COURSE_SLUG}-tester/releases/latest" | jq -r .tag_name)
tester_dir="$TESTER_CACHE/$version"
if [[ ! -x "$tester_dir/tester" ]]; then
  mkdir -p "$tester_dir"
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  [[ "$arch" == "x86_64" ]] && arch=amd64
  [[ "$arch" == "aarch64" ]] && arch=arm64
  url="https://github.com/codecrafters-io/${COURSE_SLUG}-tester/releases/download/$version/${version}_${os}_${arch}.tar.gz"
  echo "Downloading tester $version..."
  curl -fsSL "$url" | tar xz -C "$tester_dir"
fi

# Build the CODECRAFTERS_TEST_CASES_JSON payload from course-definition.yml.
test_cases_json=$(python3 - "$COURSE_DIR" "${stages[@]}" <<'PY'
import json, sys, yaml

course_dir, slugs = sys.argv[1], sys.argv[2:]
with open(f"{course_dir}/course-definition.yml") as f:
    stages = yaml.safe_load(f)["stages"]
by_slug = {s["slug"]: s for s in stages}

missing = [s for s in slugs if s not in by_slug]
if missing:
    sys.exit(f"Unknown stage slug(s): {', '.join(missing)}")

print(json.dumps([
    {
        "slug": slug,
        "tester_log_prefix": f"stage-{i + 1}",
        "title": f"Stage #{i + 1}: {by_slug[slug]['name']}",
    }
    for i, slug in enumerate(slugs)
]))
PY
)

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
