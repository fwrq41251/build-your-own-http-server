#!/usr/bin/env bash
#
# Local CodeCrafters test runner for "Build your own HTTP server" (Zig).
#
#   ./test.sh              # run the next unpassed stage
#   ./test.sh at4          # run one specific stage
#   ./test.sh at4 ia4      # run several stages in order
#   ./test.sh list         # list all stages and progress
#   ./test.sh show at4     # render a stage's instructions
#   ./test.sh show at4 --raw    # print the original Markdown
#   ./test.sh show at4 --tests  # include hidden test notes
#   ./test.sh docs         # regenerate the GitHub-friendly docs/stages/ pages
#
# Stage descriptions are rendered with glow when available, falling back to
# bat and then plain text. CC_RENDERER=auto|glow|bat|plain forces a choice.
#
# Progress is tracked in .cc-passed (one stage slug per line).
# Requires: bash, curl, awk, sed, tar. Works on Linux and macOS.
# Optional: glow or bat for prettier stage descriptions.
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

TOTAL_STAGES=$(awk 'END { print NR }' "$STAGES_FILE")

stage_name() {
  awk -F '\t' -v slug="$1" '$1 == slug { print $2; found = 1 } END { exit !found }' "$STAGES_FILE"
}

stage_exists() {
  awk -F '\t' -v slug="$1" '$1 == slug { found = 1 } END { exit !found }' "$STAGES_FILE"
}

stage_info() {
  awk -F '\t' -v slug="$1" '$1 == slug { print NR "\t" $2 "\t" $3 "\t" $4; found = 1 } END { exit !found }' "$STAGES_FILE"
}

stage_source() {
  local path=$1 local_file
  local_file="$COURSE_DIR/$path"
  if [[ -f "$local_file" ]]; then
    cat "$local_file"
  else
    # Fall back to GitHub if the course repo isn't cached locally.
    curl -fsSL "https://raw.githubusercontent.com/codecrafters-io/build-your-own-http-server/main/$path"
  fi
}

# Strip the Handlebars markers (keeping their content) and, unless requested,
# the hidden test notes in HTML comments. Also fix ```javascript fences that
# actually contain HTTP messages.
#
# Language-specific blocks ({{#lang_is_javascript}} ...) are kept only for Zig;
# other languages' notes are dropped since this repo is a Zig solution.
preprocess_markdown() {
  local show_tests=$1
  awk -v show_tests="$show_tests" '
    BEGIN { in_bot = 0; in_comment = 0; in_lang = 0 }
    /^[[:space:]]*\{\{#reader_is_bot\}\}[[:space:]]*$/ { in_bot = 1; next }
    /^[[:space:]]*\{\{\/reader_is_bot\}\}[[:space:]]*$/ { in_bot = 0; next }
    in_bot { print; next }
    /^[[:space:]]*\{\{[#\/]lang_is_[a-z0-9_]+\}\}[[:space:]]*$/ {
      tag = $0
      sub(/^[[:space:]]*\{\{[#\/]/, "", tag)
      sub(/\}\}[[:space:]]*$/, "", tag)
      if ($0 ~ /\{\{#/) in_lang = (tag == "lang_is_zig") ? 1 : 2
      else in_lang = 0
      next
    }
    in_lang == 1 { print; next }
    in_lang == 2 { next }
    {
      if (show_tests == "0") {
        if (in_comment) {
          if ($0 ~ /-->/) in_comment = 0
          next
        }
        if ($0 ~ /<!--/) {
          if ($0 !~ /-->/) in_comment = 1
          next
        }
      } else {
        sub(/<!--/, "")
        sub(/-->/, "")
      }
      if ($0 ~ /^```(javascript|js)[[:space:]]*$/) {
        print "```text"
        next
      }
      # Never leak an unknown template tag into the output.
      if ($0 ~ /^[[:space:]]*\{\{.*\}\}[[:space:]]*$/) next
      print
    }
  '
}

render_markdown() {
  local renderer=${CC_RENDERER:-auto}
  case "$renderer" in
    glow)
      if [[ -t 1 ]]; then glow -; else glow -s notty -; fi
      ;;
    bat)
      bat --language=md --style=plain --paging=never
      ;;
    plain)
      cat
      ;;
    auto)
      if command -v glow >/dev/null 2>&1; then
        if [[ -t 1 ]]; then glow -; else glow -s notty -; fi
      elif command -v bat >/dev/null 2>&1; then
        bat --language=md --style=plain --paging=never
      else
        cat
      fi
      ;;
    *)
      echo "Unknown CC_RENDERER: $renderer (use auto|glow|bat|plain)" >&2
      exit 1
      ;;
  esac
}

show_stage() {
  local slug=$1 raw=$2 show_tests=$3
  local info number name extension path passed
  info=$(stage_info "$slug") || {
    echo "Unknown stage slug: $slug (try ./test.sh list)" >&2
    exit 1
  }
  IFS=$'\t' read -r number name extension path <<< "$info"

  if [[ $raw == "1" ]]; then
    stage_source "$path"
    return
  fi

  passed=""
  if grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null; then
    passed=" · passed"
  fi

  {
    printf '# Stage #%s: %s\n\n' "$number" "$name"
    printf '> `%s` · %s · %s/%s%s\n\n---\n\n' "$slug" "$extension" "$number" "$TOTAL_STAGES" "$passed"
    if [[ $show_tests == "1" ]]; then
      printf '> **Contains hidden test notes (spoilers)**\n\n'
    fi
    stage_source "$path" | preprocess_markdown "$show_tests"
    printf '\n'
  } | render_markdown
}

# Generate GitHub-friendly Markdown for every stage under docs/stages/.
# GitHub renders these files itself, so the stage descriptions can be read
# from the repository's web UI without running any command.
write_docs() {
  local out_dir=${1:-"$PROJECT_DIR/docs/stages"}
  local slugs=() names=() groups=() paths=()
  local slug name group path number total idx prev next

  while IFS=$'\t' read -r slug name group path; do
    slugs+=("$slug")
    names+=("$name")
    groups+=("$group")
    paths+=("$path")
  done < "$STAGES_FILE"

  total=${#slugs[@]}
  mkdir -p "$out_dir"

  {
    printf '# 关卡说明\n\n'
    printf '「Build your own HTTP server」全部 %d 关的说明，从课程仓库生成，方便在 GitHub 网页上直接阅读。\n\n' "$total"
    printf '终端里仍然可以用 `./test.sh show <slug>` 查看，内容与此处一致。\n\n'
    printf '> 内容来自 [codecrafters-io/build-your-own-http-server](https://github.com/codecrafters-io/build-your-own-http-server)（MIT License）。\n'
    printf '> 已去掉模板标记、隐藏测试注释，并把 HTTP 报文代码块改为纯文本。\n\n'
    printf '| # | 关卡 | Slug | 分组 |\n'
    printf '|---:|---|---|---|\n'
    number=0
    while [[ $number -lt $total ]]; do
      number=$((number + 1))
      idx=$((number - 1))
      printf '| %d | [%s](%02d-%s.md) | `%s` | %s |\n' \
        "$number" "${names[$idx]}" "$number" "${slugs[$idx]}" "${slugs[$idx]}" "${groups[$idx]}"
    done
  } > "$out_dir/README.md"

  number=0
  while [[ $number -lt $total ]]; do
    number=$((number + 1))
    idx=$((number - 1))
    prev=""
    next=""
    if [[ $number -gt 1 ]]; then
      prev=$(printf '%02d-%s.md' "$((number - 1))" "${slugs[$((number - 2))]}")
    fi
    if [[ $number -lt $total ]]; then
      next=$(printf '%02d-%s.md' "$((number + 1))" "${slugs[$number]}")
    fi

    {
      printf '# Stage #%d: %s\n\n' "$number" "${names[$idx]}"
      printf '`%s` · %s · %d/%d\n\n' "${slugs[$idx]}" "${groups[$idx]}" "$number" "$total"
      printf '[目录](README.md)'
      [[ -n "$prev" ]] && printf ' · [← 上一关](%s)' "$prev"
      [[ -n "$next" ]] && printf ' · [下一关 →](%s)' "$next"
      printf '\n\n---\n\n'
      stage_source "${paths[$idx]}" | preprocess_markdown 0
      printf '\n---\n\n'
      printf '[目录](README.md)'
      [[ -n "$prev" ]] && printf ' · [← 上一关](%s)' "$prev"
      [[ -n "$next" ]] && printf ' · [下一关 →](%s)' "$next"
      printf '\n'
    } > "$out_dir/$(printf '%02d-%s.md' "$number" "${slugs[$idx]}")"

    printf '  %02d-%s.md\n' "$number" "${slugs[$idx]}"
  done

  printf 'Generated %d stage pages in %s\n' "$total" "$out_dir"
}

next_stage() {
  local slug
  while IFS=$'\t' read -r slug _ _ _; do
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
    while IFS=$'\t' read -r slug name extension _; do
      mark=" "
      grep -qxF "$slug" "$PASSED_FILE" 2>/dev/null && mark="x"
      printf '[%s] %-4s %-38s (%s)\n' "$mark" "$slug" "$name" "$extension"
    done < "$STAGES_FILE"
    exit 0
    ;;
  docs)
    write_docs
    exit 0
    ;;
  show)
    shift
    slug=""
    raw=0
    show_tests=0
    for arg in "$@"; do
      case "$arg" in
        --raw) raw=1 ;;
        --tests) show_tests=1 ;;
        --*)
          echo "Unknown option: $arg" >&2
          exit 1
          ;;
        *)
          if [[ -n "$slug" ]]; then
            echo "Only one stage slug is allowed for show" >&2
            exit 1
          fi
          slug=$arg
          ;;
      esac
    done
    if [[ -z "$slug" ]]; then
      slug=$(next_stage)
      if [[ -z "$slug" ]]; then
        echo "All stages passed. Nice work!"
        exit 0
      fi
    fi
    show_stage "$slug" "$raw" "$show_tests"
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
